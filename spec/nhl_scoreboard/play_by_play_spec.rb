# frozen_string_literal: true

require "json"
require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::PlayByPlay do
  let(:payload) { JSON.parse(File.read(File.expand_path("../fixtures/play_by_play_game.json", __dir__))) }
  let(:snapshots) { described_class.snapshots(payload) }
  let(:states) { snapshots.map(&:state) }

  describe ".snapshots" do
    it "reads one snapshot a second of game time, from the first play to the last" do
      # Two 20-minute periods: the game ends 2400 seconds in.
      expect(snapshots.size).to eq(2401)
      expect(snapshots.first.at).to eq(0.0)
      expect(snapshots.last.at).to eq(2400.0)
    end

    it "starts at the first faceoff with the clock at 20:00 and no goals" do
      first = states.first
      expect(first.phase).to eq(:regulation)
      expect(first.clock).to eq("20:00")
      expect([first.home_team.score, first.away_team.score]).to eq([0, 0])
      expect(first.goals).to eq([])
    end

    it "interpolates the clock between two plays in a straight line" do
      # The faceoff at 20:00 and the goal at 18:00 are 120 seconds apart.
      expect(states[60].clock).to eq("19:00")
      expect(states[119].clock).to eq("18:01")
    end

    it "shows a goal from the second it was scored, with the score and the scorer" do
      expect(states[119].home_team.score).to eq(0)
      expect(states[120].home_team.score).to eq(1)
      expect(states[120].goals.map(&:scorer)).to eq(["Synthetic Scorer"])
      expect(states[120].goals.first.tri_code).to eq("COL")
    end

    it "names a scorer missing from the roster by its player id" do
      expect(states[600].goals.last.scorer).to eq("8002")
      expect(states[600].goals.last.tri_code).to eq("CHI")
    end

    it "counts the clock down within each period, never up" do
      states.group_by(&:period).each_value do |period_states|
        seconds = period_states.map { |state| state.clock.split(":").map(&:to_i).then { |m, s| m * 60 + s } }
        expect(seconds).to eq(seconds.sort.reverse)
      end
    end

    it "moves into the second period at 20:00 and keeps the second-period goal" do
      second = states[1200]
      expect(second.period).to eq(2)
      expect(second.clock).to eq("20:00")
      expect(second.goals.map(&:clock)).to eq(["18:00", "10:00"])
    end

    it "ends in the final phase with the final score and goals" do
      last = states.last
      expect(last.phase).to eq(:final)
      expect(last.clock).to eq("00:00")
      expect([last.home_team.score, last.away_team.score]).to eq([2, 1])
      expect(last.goals.size).to eq(3)
    end

    it "keeps the game's teams on every state" do
      expect(states.map { |state| state.home_team.tri_code }.uniq).to eq(["COL"])
      expect(states.map { |state| state.away_team.tri_code }.uniq).to eq(["CHI"])
    end

    it "gives a recording that replays with the same states" do
      replayed = NhlScoreboard::GameSequence.replay(snapshots).first(3)
      expect(replayed).to eq(states.first(3))
    end

    it "returns nothing for a game with no plays" do
      expect(described_class.snapshots(payload.merge("plays" => []))).to eq([])
    end

    it "raises when the payload's plays are missing" do
      expect { described_class.snapshots(payload.except("plays")) }
        .to raise_error(NhlScoreboard::Error, /isn't shaped as expected/)
    end

    it "raises when a clock isn't MM:SS" do
      bad = payload.merge("plays" => [payload["plays"].first.merge("timeRemaining" => "soon")])
      expect { described_class.snapshots(bad) }.to raise_error(NhlScoreboard::Error, /MM:SS/)
    end
  end
end
