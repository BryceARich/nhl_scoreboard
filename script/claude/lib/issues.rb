# frozen_string_literal: true

# Shared helpers for the script/claude/* tools, adapted from sports_ingest. Plain Ruby stdlib plus
# the `gh` and `git` CLIs, compatible with macOS system Ruby (2.6).
require "json"
require "open3"

# gh output is UTF-8; don't depend on the shell's locale.
Encoding.default_external = Encoding::UTF_8

# Finds issues that are ready to start, and talks to the project board.
module ClaudeScripts
  PROJECT = "1" # project board number, under the repo owner (shared with sports_ingest)
  TITLE_RE = /\A\[C(\d+)-(\d+)\]\s*(.*)\z/
  # A blocker: "#12" in this repo, or "owner/repo#12" in another one.
  BLOCKER_RE = %r{([\w.-]+/[\w.-]+)?#(\d+)}
  # The repo is public, so anyone can open an issue or comment. Only text from people with a role
  # on the repo is acted on, so a stranger can't steer a session that holds a GitHub token.
  TRUSTED_ASSOCIATIONS = %w[OWNER MEMBER COLLABORATOR].freeze
  # Override per clone with `git config claude.modelDefault` / `claude.modelDesign`.
  DESIGN_LABEL = "needs-decision"
  MODEL_DEFAULT = "claude-sonnet-5-5"
  MODEL_DESIGN = "claude-opus-5-5"

  module_function

  # Runs a command and returns its output.
  #
  # @param cmd [Array<String>] the command and its arguments
  # @param env [Hash] extra environment variables
  # @param allow_fail [Boolean] return nil on failure instead of aborting
  # @return [String, nil] stdout, or nil when it failed and +allow_fail+ is set
  # @raise [SystemExit] when the command fails and +allow_fail+ isn't set
  # @example
  #   run("git", "status")
  def run(*cmd, env: {}, allow_fail: false)
    out, err, status = Open3.capture3(env, *cmd)
    return out if status.success?
    return nil if allow_fail

    abort "error: `#{cmd.first(4).join(" ")} ...` failed:\n#{err.strip}"
  end

  # Names the GitHub repo this clone points at.
  #
  # @return [String] "owner/name"
  # @raise [SystemExit] when gh fails
  # @example
  #   repo # => "BryceARich/nhl_scoreboard"
  def repo
    @repo ||= run("gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner").strip
  end

  # Names the repo's owner.
  #
  # @return [String] the owner's login
  # @raise [SystemExit] when gh fails
  # @example
  #   owner # => "BryceARich"
  def owner
    repo.split("/").first
  end

  # Reads a git config value.
  #
  # @param key [String] the git config key
  # @return [String, nil] its value, or nil when unset
  # @example
  #   local_config("claude.botUser") # => "BryceAIRich"
  def local_config(key)
    v = run("git", "config", "--get", key, allow_fail: true).to_s.strip
    v.empty? ? nil : v
  end

  # Builds the environment for gh calls as the bot (docs/BOT_ACCOUNT.md).
  #
  # @return [Hash] GH_TOKEN for the bot, or empty when GH_TOKEN is already set
  # @raise [SystemExit] when no bot is configured or it isn't logged in to gh
  # @example
  #   run("gh", "api", "user", env: bot_env)
  def bot_env
    return {} if ENV["GH_TOKEN"]

    bot = local_config("claude.botUser") || abort("error: claude.botUser isn't set; see docs/BOT_ACCOUNT.md")
    @bot_env ||= {"GH_TOKEN" => run("gh", "auth", "token", "--user", bot).strip}
  end

  # Runs gh with a --jq filter that emits one compact JSON value per line.
  #
  # @param args [Array<String>] gh arguments
  # @param env [Hash] extra environment variables
  # @return [Array] the parsed values
  # @raise [SystemExit] when gh fails
  # @example
  #   gh_lines("api", "user", "--jq", "{login}")
  def gh_lines(*args, env: {})
    run("gh", *args, env: env).each_line.map { |l| JSON.parse(l) }
  end

  # Tells whether an issue's author has a role on the repo.
  #
  # @param issue [Hash] an issue from {all_issues}
  # @return [Boolean] whether sessions may act on it
  # @example
  #   trusted?({"association" => "NONE"}) # => false
  def trusted?(issue)
    TRUSTED_ASSOCIATIONS.include?(issue["association"])
  end

  # Reads the build order from an issue title.
  #
  # @param title [String] the issue title
  # @return [Array(Integer, Integer), nil] milestone and item, or nil when it has none
  # @example
  #   build_order("[C1-05] Goal ticker") # => [1, 5]
  def build_order(title)
    m = TITLE_RE.match(title)
    m && [m[1].to_i, m[2].to_i]
  end

  # Formats an issue's build order.
  #
  # @param issue [Hash] an issue with a build order in its title
  # @return [String] the label
  # @example
  #   label({"title" => "[C1-05] Goal ticker"}) # => "C1-05"
  def label(issue)
    format("C%d-%02d", *build_order(issue["title"]))
  end

  # Names the branch for an issue.
  #
  # @param issue [Hash] an issue with a build order in its title
  # @return [String] the branch name, at most 40 characters
  # @example
  #   branch_name({"title" => "[C1-05] Goal ticker"}) # => "c1-05-goal-ticker"
  def branch_name(issue)
    words = TITLE_RE.match(issue["title"])[3].downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
    "#{label(issue).downcase}-#{words}"[0, 40].sub(/-+\z/, "")
  end

  # Picks the model a session should run.
  #
  # @param issue [Hash] an issue from {all_issues}
  # @return [String] a model id: the design model for `needs-decision` issues
  # @example
  #   model_for({"labels" => []}) # => "claude-sonnet-5-5"
  def model_for(issue)
    if (issue["labels"] || []).include?(DESIGN_LABEL)
      local_config("claude.modelDesign") || MODEL_DESIGN
    else
      local_config("claude.modelDefault") || MODEL_DEFAULT
    end
  end

  # Fetches every issue (no PRs), trimmed to the fields used here.
  #
  # @return [Array<Hash>] the issues
  # @raise [SystemExit] when gh fails
  # @example
  #   all_issues.map { |i| i["number"] }
  def all_issues
    gh_lines("api", "repos/#{repo}/issues?state=all&per_page=100", "--paginate",
      "--jq", ".[] | select(.pull_request | not) | {number, title, state, body, labels: [.labels[].name], " \
              "author: .user.login, association: .author_association}")
  end

  # Lists the blockers under "## Blocked by" in an issue's body (HTML comments ignored).
  #
  # @param issue [Hash] an issue from {all_issues}
  # @return [Array<Array(String, Integer)>] repo and issue number of each
  # @raise [SystemExit] when gh fails
  # @example
  #   body_blockers({"body" => "## Blocked by\n- o/lib#4"}) # => [["o/lib", 4]]
  def body_blockers(issue)
    body = (issue["body"] || "").gsub(/<!--.*?-->/m, "")
    section = body[/^##\s*Blocked by\s*$(.*?)(?=^##\s|\z)/m, 1] || ""
    section.scan(BLOCKER_RE).map { |r, n| [r || repo, n.to_i] }
  end

  # Lists GitHub's native "blocked by" links that are still open.
  #
  # @param number [Integer] the issue number
  # @return [Array<Array(String, Integer)>] repo and issue number of each
  # @raise [SystemExit] when gh fails
  # @example
  #   native_open_blockers(9) # => [["BryceARich/nhl_scoreboard", 1]]
  def native_open_blockers(number)
    gh_lines("api", "repos/#{repo}/issues/#{number}/dependencies/blocked_by",
      "--jq", '.[] | select(.state != "closed") | {number, repo: (.repository_url | sub(".*/repos/"; ""))}')
      .map { |h| [h["repo"], h["number"]] }
  end

  # Tells whether a blocker is closed. One that can't be read counts as open.
  #
  # @param name [String] "owner/repo"
  # @param number [Integer] the issue number
  # @param states [Hash] number => state for this repo's issues
  # @return [Boolean] whether it's closed
  # @example
  #   blocker_closed?("o/lib", 4, {})
  def blocker_closed?(name, number, states)
    return states[number] == "closed" if name.casecmp?(repo)

    @external ||= {}
    key = "#{name}##{number}"
    @external[key] ||= run("gh", "api", "repos/#{name}/issues/#{number}", "--jq", ".state", allow_fail: true).to_s.strip
    @external[key] == "closed"
  end

  # Lists an issue's open blockers, from its body and GitHub's links, in this repo and others.
  #
  # @param issue [Hash] an issue from {all_issues}
  # @param states [Hash] number => state for this repo's issues
  # @return [Array<String>] such as "#2" or "owner/repo#4"
  # @raise [SystemExit] when gh fails
  # @example
  #   open_blockers(issue, {2 => "open"}) # => ["#2"]
  def open_blockers(issue, states)
    blockers = body_blockers(issue).reject { |name, n| blocker_closed?(name, n, states) }
    (blockers + native_open_blockers(issue["number"]))
      .map { |name, n| name.casecmp?(repo) ? "##{n}" : "#{name}##{n}" }.uniq
  end

  # Reads this repo's items on the project board.
  #
  # @return [Hash] issue number => item ("status", "id")
  # @raise [SystemExit] when gh fails
  # @example
  #   board_items.dig(2, "status") # => "Todo"
  def board_items
    gh_lines("project", "item-list", PROJECT, "--owner", owner, "--format", "json", "--limit", "500",
      "--jq", '.items[] | select(.content.type == "Issue") | ' \
              "{n: .content.number, repo: .content.repository, status: .status, id: .id}")
      .select { |h| h["repo"].to_s.casecmp?(repo) }
      .map { |h| [h["n"], h] }.to_h
  end

  # Lists the issues that an open PR says it closes.
  #
  # @return [Array<Integer>] issue numbers
  # @raise [SystemExit] when gh fails
  # @example
  #   issues_with_open_prs # => [2]
  def issues_with_open_prs
    gh_lines("pr", "list", "-R", repo, "--state", "open", "--limit", "200", "--json", "body", "--jq", ".[] | {body}")
      .flat_map { |h| (h["body"] || "").scan(/\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+#(\d+)/i) }
      .flatten.map(&:to_i)
  end

  # Lists branches on origin and in this clone (worktrees included).
  #
  # @return [Array<String>] branch names
  # @raise [SystemExit] when git fails
  # @example
  #   existing_branches # => ["main"]
  def existing_branches
    remote = run("git", "ls-remote", "--heads", "origin").scan(%r{refs/heads/(\S+)}).flatten
    remote + run("git", "branch", "--format=%(refname:short)").split("\n")
  end

  # Sorts open issues into those ready to start and those not, in build order.
  #
  # @return [Array(Array<Hash>, Array<Hash>)] ready and skipped; each entry has :issue, :branch, :reason
  # @raise [SystemExit] when gh or git fails
  # @example
  #   ready, skipped = classify
  def classify
    issues = all_issues
    states = issues.map { |i| [i["number"], i["state"]] }.to_h
    open = issues.select { |i| i["state"] == "open" && build_order(i["title"]) }
      .sort_by { |i| build_order(i["title"]) }
    board = board_items
    pr_issues = issues_with_open_prs
    branches = existing_branches

    open.map do |issue|
      n = issue["number"]
      prefix = "#{label(issue).downcase}-"
      status = board.dig(n, "status")
      reason =
        if !trusted?(issue) then "opened by #{issue["author"]}, who has no role on the repo"
        elsif !(blockers = open_blockers(issue, states)).empty? then "blocked by #{blockers.join(", ")}"
        elsif status && status != "Todo" then "status is #{status}"
        elsif pr_issues.include?(n) then "has an open PR"
        elsif branches.any? { |b| b.split("/").last.start_with?(prefix) } then "branch #{prefix}* exists"
        end
      {issue: issue, branch: branch_name(issue), reason: reason}
    end.partition { |r| r[:reason].nil? }
  end
end
