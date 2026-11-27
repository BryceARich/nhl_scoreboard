# frozen_string_literal: true

require "json"
require "stringio"
require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::NightReplay do
  # Three games on one night, starting 0, 600 and 1800 seconds in. Each game has its own home team
  # code, so the boards can be told apart. The fixture's game lasts 2400 seconds of game time.
  let(:base) { 1_800_000_000 }
  let(:payload) { JSON.parse(File.read(File.expand_path("../fixtures/play_by_play_game.json", __dir__))) }

  def game(start, home_code)
    game_payload = payload.merge("homeTeam" => payload["homeTeam"].merge("abbrev" => home_code))
    NhlScoreboard::PlayByPlay.snapshots(game_payload, start: start)
  end

  let(:night) { described_class.new([game(base, "COL"), game(base + 600, "VGK"), game(base + 1800, "NJD")]) }

  describe "#seconds_into_period" do
    it "gives the moment a team's game reaches the period, as seconds into the night" do
      seconds = night.seconds_into_period("COL", 2)
      expect(seconds).to be_a(Float)
      expect(night.states_at(seconds).find { |state| state.home_team.tri_code == "COL" }.period).to be >= 2
    end

    it "is nil for a team not playing tonight, or a period no game reaches" do
      expect(night.seconds_into_period("TOR", 1)).to be_nil
      expect(night.seconds_into_period("COL", 9)).to be_nil
    end
  end

  describe "#states_at" do
    it "starts at the first game and adds each game as it starts" do
      expect(night.states_at(0).map { |state| state.home_team.tri_code }).to eq(["COL"])
      expect(night.states_at(599).size).to eq(1)
      expect(night.states_at(600).map { |state| state.home_team.tri_code }).to eq(["COL", "VGK"])
      expect(night.states_at(1800).size).to eq(3)
    end

    it "shows each game in the state its clock is at" do
      # The first game is 120 seconds in at 2 minutes, with its first goal just scored.
      first = night.states_at(120).first
      expect(first.clock).to eq("18:00")
      expect(first.home_team.score).to eq(1)
    end

    it "keeps a finished game on the boards as final" do
      finals = night.states_at(night.duration + 1000)
      expect(finals.map(&:phase)).to eq([:final, :final, :final])
    end

    it "has no games before the night starts" do
      expect(night.states_at(-1)).to eq([])
    end
  end

  describe "#origin and #duration" do
    it "starts at the earliest game and ends with the last game's last snapshot" do
      expect(night.origin).to eq(base.to_f)
      # The last game starts 1800 seconds in and its fixture lasts 2400 seconds.
      expect(night.duration).to eq(4200.0)
    end
  end

  describe "a night of games" do
    it "refuses a night with no snapshots" do
      expect { described_class.new([[], []]) }.to raise_error(NhlScoreboard::Error, /at least one game/)
    end

    it "leaves out games with no snapshots" do
      expect(described_class.new([[], game(base, "COL")]).size).to eq(1)
    end
  end

  # Plays the night through the main loop, one tick at a time on a clock the test controls, and
  # records each draw. The loop, picker and grid are the ones bin/scoreboard uses; only the display
  # is replaced, so the test checks what the loop chooses.
  def play_night(night, panels:, columns:, seconds:)
    grid = NhlScoreboard::BoardGrid.new(boards: panels, columns: columns)
    picker = NhlScoreboard::GamePicker.new(dwell: 10, board_count: grid.boards)
    now = 0.0
    draws = []
    display = Object.new
    display.define_singleton_method(:show) do |boards, step: 0|
      draws << [now, boards]
      nil
    end
    loop = NhlScoreboard::MainLoop.new(source: -> { night.states_at(now) }, display: display, picker: picker,
      poll_interval: ->(_game) { 1 }, clock: -> { now }, logger: StringIO.new)
    # The loop wakes every SCROLL_SECONDS; time comes from a tick count, so the clock never drifts.
    (0..(seconds / NhlScoreboard::MainLoop::SCROLL_SECONDS).round).each do |i|
      now = i * NhlScoreboard::MainLoop::SCROLL_SECONDS
      loop.tick(now)
    end
    draws
  end

  # Each board/column variation: the number of boards on the panels, and how many per row.
  variations = [[1, 1], [2, 1], [2, 2], [3, 2], [4, 2]]

  variations.each do |panels, columns|
    context "on #{panels} boards in #{columns} #{(columns == 1) ? "column" : "columns"}" do
      let(:draws) { play_night(night, panels: panels, columns: columns, seconds: 4300) }

      it "shows as many boards as there are games still on the boards, up to the boards" do
        draws.each do |now, boards|
          # A game is on the boards from its start until one dwell (10 s) after it goes final, 2400 s in.
          on_boards = [0, 600, 1800].count { |start| now >= start && now < start + 2400 + 10 }
          expect(boards.size).to eq([panels, on_boards].min), "at #{now}s"
        end
      end

      it "never shows the same game twice in one draw" do
        draws.each do |_now, boards|
          codes = boards.map { |board| board.home_team.tri_code }
          expect(codes.uniq.size).to eq(codes.size), "boards #{codes.inspect}"
        end
      end

      it "gives every game a turn on the boards over the night" do
        shown = draws.flat_map { |_now, boards| boards.map { |board| board.home_team.tri_code } }.uniq
        expect(shown).to match_array(["COL", "VGK", "NJD"])
      end
    end
  end

  variations.each do |panels, columns|
    it "draws #{panels} boards in #{columns} #{(columns == 1) ? "column" : "columns"} on a canvas that fits them" do
      grid = NhlScoreboard::BoardGrid.new(boards: panels, columns: columns)
      font = NhlScoreboard::BdfFont.load(File.expand_path("../fixtures/tiny.bdf", __dir__))
      settings = NhlScoreboard::MatrixSettings.new(rows: grid.height, cols: grid.width, chain_length: 1)
      matrix = NhlScoreboard::FakeMatrix.new(settings)
      display = NhlScoreboard::GameDisplay.new(matrix, NhlScoreboard::ScoreboardLayout.new(font),
        NhlScoreboard::LogoLibrary.load, ticker: NhlScoreboard::GoalTicker.new(font), grid: grid)
      boards = night.states_at(2000).first(grid.boards)

      expect { display.show(boards) }.not_to raise_error
    end
  end
end
