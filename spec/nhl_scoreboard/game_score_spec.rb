# frozen_string_literal: true

require "stringio"
require_relative "../../lib/nhl_scoreboard"

begin
  require "sports_ingest/nhl"
rescue LoadError
  nil
end

# The layout, the picker and the loop on a real SportsIngest::NHL::GameScore, not a fake (ADR 0005,
# follow-up). Offline: each game is built in place. Skipped when the gem isn't installed.
RSpec.describe "a real SportsIngest::NHL::GameScore", if: defined?(SportsIngest::NHL::GameScore) do
  let(:matrix) { NhlScoreboard::FakeMatrix.new(NhlScoreboard::MatrixSettings.new(rows: 32, cols: 64, chain_length: 1)) }
  let(:font) { NhlScoreboard::BdfFont.load(File.expand_path("../fixtures/tiny.bdf", __dir__)) }
  let(:logos) { NhlScoreboard::LogoLibrary.load }
  let(:display) { NhlScoreboard::GameDisplay.new(matrix, NhlScoreboard::ScoreboardLayout.new(font), logos) }

  # Builds a GameScore for one state of play, as the gem's own specs do.
  def score(home: "COL", away: "CHI", state: :live, ended_in: nil, **fields)
    game = {id: "2026020001", season: 2026, game_type: :regular, date: "2026-11-23", start_time: "2026-11-24T00:00:00Z",
            state: state, schedule_state: :ok, ended_in: ended_in,
            home_team: {id: 1, tri_code: home, score: 2}, away_team: {id: 2, tri_code: away, score: 1}}
    SportsIngest::NHL::GameScore.new(game: game, **fields)
  end

  it "draws a live game, with the home team's logo in its slot" do
    live = score(state: :live, period: 2, period_type: :regulation, seconds_remaining: 754)
    shown = display.show(live)
    expect(shown.pixel(0, 2)).to eq(logos.fetch("avalanche").pixel(0, 0))
  end

  it "draws a game before the puck drops, with no period or clock" do
    expect { display.show(score(state: :scheduled)) }.not_to raise_error
  end

  it "draws a final game" do
    final = score(state: :final, period: 3, period_type: :regulation, seconds_remaining: 0, ended_in: :regulation)
    expect { display.show(final) }.not_to raise_error
  end

  it "the loop polls a live game at the gem's rate and shows it on the first board" do
    live = score(state: :live, period: 1, period_type: :regulation, seconds_remaining: 600)
    shown = []
    shown_display = Object.new
    shown_display.define_singleton_method(:show) { |game| shown << game }
    loop_ = NhlScoreboard::MainLoop.new(
      source: -> { [live] },
      display: shown_display,
      picker: NhlScoreboard::GamePicker.new(favorite: "COL", dwell: 10),
      poll_interval: ->(game) { SportsIngest::NHL::PollInterval.for(game) },
      logger: StringIO.new
    )
    expect(loop_.tick(0)).to eq(10)
    expect(shown).to eq([[live]])
  end
end
