# frozen_string_literal: true

require "tmpdir"
require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::GameRecording do
  let(:fixture) { File.expand_path("../fixtures/replay_game.jsonl", __dir__) }
  let(:state) { NhlScoreboard::GameState.load(File.expand_path("../../assets/demo_game.json", __dir__)) }

  around do |example|
    Dir.mktmpdir { |dir| @dir = dir and example.run }
  end

  describe ".append and .read" do
    it "round-trips each state with its read time, in order" do
      path = File.join(@dir, "game.jsonl")
      described_class.append(path, state, at: 1000)
      described_class.append(path, state.with(clock: "12:00"), at: 1001.5)

      snapshots = described_class.read(path)
      expect(snapshots.map(&:at)).to eq([1000.0, 1001.5])
      expect(snapshots.map(&:state)).to eq([state, state.with(clock: "12:00")])
    end

    it "reads the synthetic fixture that ships with the specs" do
      snapshots = described_class.read(fixture)
      expect(snapshots.size).to eq(4)
      expect(snapshots.last.state.home_team.score).to eq(1)
      expect(snapshots.last.state.goals.first.scorer).to eq("Synthetic Scorer")
    end

    it "refuses a read time that isn't a number" do
      expect { described_class.append(File.join(@dir, "x.jsonl"), state, at: "noon") }
        .to raise_error(NhlScoreboard::Error, /must be a number/)
    end

    it "names the line when a line has no read time" do
      path = File.join(@dir, "game.jsonl")
      File.write(path, "#{JSON.generate(state.as_hash)}\n")
      expect { described_class.read(path) }.to raise_error(NhlScoreboard::Error, /:1 has no read time/)
    end

    it "names the line when a line isn't valid JSON" do
      path = File.join(@dir, "game.jsonl")
      File.write(path, "{not json\n")
      expect { described_class.read(path) }.to raise_error(NhlScoreboard::Error, /:1 is not valid JSON/)
    end

    it "names the line when a line isn't a game state" do
      path = File.join(@dir, "game.jsonl")
      File.write(path, "{\"at\": 1, \"phase\": \"tuesday\"}\n")
      expect { described_class.read(path) }.to raise_error(NhlScoreboard::Error, /:1: phase must be one of/)
    end

    it "raises a clear error when the file is missing" do
      expect { described_class.read(File.join(@dir, "missing.jsonl")) }
        .to raise_error(NhlScoreboard::Error, /cannot read recording/)
    end

    it "skips blank lines" do
      path = File.join(@dir, "game.jsonl")
      described_class.append(path, state, at: 1)
      File.write(path, "\n", mode: "a")
      expect(described_class.read(path).size).to eq(1)
    end
  end
end
