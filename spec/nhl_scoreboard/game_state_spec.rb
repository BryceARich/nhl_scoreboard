# frozen_string_literal: true

require "tmpdir"
require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::GameState do
  let(:data) do
    {
      "phase" => "regulation", "period" => 2, "period_type" => "regulation", "clock" => "05:00",
      "home_team" => {"tri_code" => "COL", "score" => 3},
      "away_team" => {"tri_code" => "CHI", "score" => 2},
      "goals" => [{"tri_code" => "COL", "period" => 2, "clock" => "05:10", "scorer" => "Someone"}]
    }
  end

  it "reads a state from a Hash, with symbols for the coded fields" do
    state = described_class.from_h(data)
    expect(state.phase).to eq(:regulation)
    expect(state.period_type).to eq(:regulation)
    expect(state.clock).to eq("05:00")
    expect(state.home_team).to eq(NhlScoreboard::GameState::Team.new(tri_code: "COL", score: 3))
    expect(state.goals.first.scorer).to eq("Someone")
  end

  it "reads the demo file that ships with the repo" do
    state = described_class.load(File.expand_path("../../assets/demo_game.json", __dir__))
    expect(state.home_team.tri_code).to eq("COL")
  end

  it "has no goals when the list is missing, and no period type when it is absent" do
    state = described_class.from_h(data.except("goals", "period_type"))
    expect(state.goals).to eq([])
    expect(state.period_type).to be_nil
  end

  it "rejects a phase the layout doesn't know" do
    expect { described_class.from_h(data.merge("phase" => "warp")) }
      .to raise_error(NhlScoreboard::Error, /phase must be one of/)
  end

  it "rejects a state missing a team" do
    expect { described_class.from_h(data.except("away_team")) }
      .to raise_error(NhlScoreboard::Error, /missing "away_team"/)
  end

  it "rejects a file that isn't JSON" do
    path = File.join(Dir.tmpdir, "not-json-#{Process.pid}.json")
    File.write(path, "{")
    expect { described_class.load(path) }.to raise_error(NhlScoreboard::Error, /not valid JSON/)
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  it "returns a copy with some fields changed, and leaves the original alone" do
    state = described_class.from_h(data)
    changed = state.with(clock: "00:30")
    expect(changed.clock).to eq("00:30")
    expect(changed.home_team).to eq(state.home_team)
    expect(state.clock).to eq("05:00")
  end
end
