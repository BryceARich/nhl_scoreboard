# frozen_string_literal: true

require_relative "../../script/claude/lib/issues"

RSpec.describe ClaudeScripts do
  # A fresh copy per example, so memoized values don't leak; gh and git are always stubbed.
  subject(:scripts) { described_class.dup }

  def issue(number, title, body: "", state: "open", association: "OWNER")
    {"number" => number, "title" => title, "body" => body, "state" => state, "labels" => [],
     "author" => "someone", "association" => association}
  end

  before do
    allow(scripts).to receive(:run) { |*cmd, **| raise "unexpected command: #{cmd.join(" ")}" }
    allow(scripts).to receive_messages(repo: "o/app", local_config: nil, native_open_blockers: [],
      board_items: {}, issues_with_open_prs: [], existing_branches: ["main"])
  end

  def external(state)
    allow(scripts).to receive(:run)
      .with("gh", "api", "repos/o/lib/issues/4", "--jq", ".state", allow_fail: true).and_return(state)
  end

  describe ".body_blockers" do
    it "tells this repo's issues from another repo's" do
      body = "## Task\n#99\n\n## Blocked by\n- #2 [C1-01] X\n- o/lib#4 [M1-01] Y\n<!-- #5 -->\n\n## Definition of Done\n#7"
      expect(scripts.body_blockers(issue(3, "[C1-02] Z", body: body))).to eq([["o/app", 2], ["o/lib", 4]])
    end
  end

  describe ".open_blockers" do
    let(:blocked) { issue(3, "[C1-02] Z", body: "## Blocked by\n- o/lib#4") }

    it "checks another repo's blocker there, not against the same number here" do
      external("open\n")
      expect(scripts.open_blockers(blocked, {4 => "closed"})).to eq(["o/lib#4"])
    end

    it "clears a closed blocker in another repo" do
      external("closed\n")
      expect(scripts.open_blockers(blocked, {4 => "open"})).to be_empty
    end

    it "treats a blocker it can't read as open" do
      external(nil)
      expect(scripts.open_blockers(blocked, {})).to eq(["o/lib#4"])
    end

    it "adds GitHub's native links" do
      allow(scripts).to receive(:native_open_blockers).and_return([["o/app", 2]])
      expect(scripts.open_blockers(issue(3, "[C1-02] Z"), {})).to eq(["#2"])
    end
  end

  describe ".classify" do
    def reasons(*issues)
      allow(scripts).to receive(:all_issues).and_return(issues)
      ready, skipped = scripts.classify
      [ready.map { |r| r[:branch] }, skipped.map { |s| s[:reason] }]
    end

    it "lists ready issues in build order and skips unplanned or closed ones" do
      expect(reasons(issue(9, "[C1-08] CI workflow"), issue(2, "[C1-01] FFI: C API"),
        issue(5, "A bug"), issue(1, "[C1-00] Docs", state: "closed")))
        .to eq([%w[c1-01-ffi-c-api c1-08-ci-workflow], []])
    end

    it "skips issues from people with no role on the repo" do
      expect(reasons(issue(2, "[C1-01] X", association: "NONE")).last.first).to include("no role")
    end

    it "skips issues already taken" do
      allow(scripts).to receive_messages(board_items: {2 => {"status" => "In Progress"}},
        issues_with_open_prs: [3], existing_branches: ["claude/c1-03-logos"])
      expect(reasons(issue(2, "[C1-01] X"), issue(3, "[C1-02] Y"), issue(4, "[C1-03] Z")))
        .to eq([[], ["status is In Progress", "has an open PR", "branch c1-03-* exists"]])
    end
  end

  it "routes needs-decision issues to the design model" do
    expect(scripts.model_for({"labels" => ["needs-decision"]})).to eq(described_class::MODEL_DESIGN)
    expect(scripts.model_for({"labels" => []})).to eq(described_class::MODEL_DEFAULT)
  end
end
