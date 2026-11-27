# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::GameSequence do
  let(:state) do
    NhlScoreboard::GameState.new(
      phase: :regulation, period: 1, period_type: :regulation, clock: "00:02",
      home_team: NhlScoreboard::GameState::Team.new(tri_code: "COL", score: 3),
      away_team: NhlScoreboard::GameState::Team.new(tri_code: "CHI", score: 2),
      goals: []
    )
  end

  describe ".countdown" do
    it "counts the clock down to 00:00, one state a second, starting with the given clock" do
      expect(described_class.countdown(state).map(&:clock)).to eq(["00:02", "00:01", "00:00"])
    end

    it "keeps everything but the clock" do
      expect(described_class.countdown(state).map(&:home_team).uniq).to eq([state.home_team])
    end

    it "counts down from minutes" do
      expect(described_class.countdown(state.with(clock: "01:00")).map(&:clock).first(3))
        .to eq(["01:00", "00:59", "00:58"])
    end

    it "raises when the state has no clock" do
      expect { described_class.countdown(state.with(clock: nil)) }
        .to raise_error(NhlScoreboard::Error, /needs a clock/)
    end

    it "raises when the clock isn't MM:SS" do
      expect { described_class.countdown(state.with(clock: "soon")) }
        .to raise_error(NhlScoreboard::Error, /MM:SS/)
    end
  end

  describe ".cycle_home_logos" do
    it "puts every current team in the home slot in turn, then starts again" do
      codes = described_class.cycle_home_logos(state).take(33).map { |frame| frame.home_team.tri_code }
      expect(codes.first(32)).to eq(NhlScoreboard::TeamLogos::FILES.keys)
      expect(codes.last).to eq(codes.first)
    end

    it "keeps the home score and the away team" do
      frames = described_class.cycle_home_logos(state).take(3)
      expect(frames.map { |frame| frame.home_team.score }.uniq).to eq([3])
      expect(frames.map(&:away_team).uniq).to eq([state.away_team])
    end
  end
end
