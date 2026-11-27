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

  describe ".replay" do
    let(:fixture) { File.expand_path("../fixtures/replay_game.jsonl", __dir__) }
    let(:snapshots) { NhlScoreboard::GameRecording.read(fixture) }

    def snap(at, clock)
      NhlScoreboard::GameRecording::Snapshot.new(at, state.with(clock: clock))
    end

    it "shows one frame a second, each the newest read at or before that second" do
      # Reads at 0, 1, 2.5 and 4: seconds 0 and 1 show their own read, second 2 still shows the read
      # at 1, second 3 shows the read at 2.5, and second 4 the last.
      frames = described_class.replay([snap(0, "12:00"), snap(1, "11:59"), snap(2.5, "11:57"), snap(4, "11:55")])
      expect(frames.map(&:clock)).to eq(["12:00", "11:59", "11:59", "11:57", "11:55"])
    end

    it "holds the last state across a gap between reads" do
      frames = described_class.replay([snap(0, "12:00"), snap(3, "11:57")])
      expect(frames.map(&:clock)).to eq(["12:00", "12:00", "12:00", "11:57"])
    end

    it "plays the synthetic fixture, with its goal, at the right frames" do
      frames = described_class.replay(snapshots).to_a
      expect(frames.size).to eq(5)
      expect(frames.map { |frame| frame.home_team.score }).to eq([0, 0, 0, 1, 1])
    end

    it "sorts reads given out of order by their time" do
      frames = described_class.replay([snap(1, "11:59"), snap(0, "12:00")])
      expect(frames.map(&:clock)).to eq(["12:00", "11:59"])
    end

    it "shows a single read as a single frame" do
      expect(described_class.replay([snap(5, "12:00")]).to_a.map(&:clock)).to eq(["12:00"])
    end

    it "starts again from the first read each time it is walked" do
      frames = described_class.replay([snap(0, "12:00"), snap(1, "11:59")])
      expect(frames.first(2).map(&:clock)).to eq(["12:00", "11:59"])
      expect(frames.first(2).map(&:clock)).to eq(["12:00", "11:59"])
    end

    it "raises when there are no snapshots" do
      expect { described_class.replay([]) }.to raise_error(NhlScoreboard::Error, /at least one snapshot/)
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
