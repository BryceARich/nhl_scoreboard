# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::GoalTicker do
  let(:font) { NhlScoreboard::BdfFont.load(File.expand_path("../fixtures/tiny.bdf", __dir__)) }
  let(:ticker) { described_class.new(font) }
  let(:canvas) { NhlScoreboard::FakeCanvas.new(width: 128, height: 32) }

  def goal(tri_code: "COL", scorer: "ILL", clock: "12:34", period: 1)
    NhlScoreboard::GameState::Goal.new(tri_code: tri_code, period: period, clock: clock, scorer: scorer)
  end

  def game(*goals)
    NhlScoreboard::GameState.new(
      phase: :regulation, period: 1, period_type: :regulation, clock: "12:34",
      home_team: NhlScoreboard::GameState::Team.new(tri_code: "COL", score: 1),
      away_team: NhlScoreboard::GameState::Team.new(tri_code: "CHI", score: 0),
      goals: goals
    )
  end

  # Every lit pixel in the ticker's columns, as [x, y, rgb].
  def lit_ticker_pixels(canvas)
    (64...128).flat_map do |x|
      (0...32).filter_map do |y|
        rgb = canvas.pixel(x, y)
        [x, y, rgb] if rgb.any?(&:positive?)
      end
    end
  end

  it "draws nothing when the game has no goals" do
    ticker.draw(canvas, game, step: 0)
    expect(lit_ticker_pixels(canvas)).to be_empty
  end

  it "draws the latest goal in the scoring team's colour" do
    ticker.draw(canvas, game(goal(tri_code: "COL"), goal(tri_code: "CHI")), step: 10)
    colours = lit_ticker_pixels(canvas).map(&:last).uniq
    expect(colours).to eq([NhlScoreboard::TeamColors.rgb_for("CHI")])
  end

  it "scrolls the text leftwards as the step grows" do
    ticker.draw(canvas, game(goal), step: 10)
    first = lit_ticker_pixels(canvas)
    canvas.clear
    ticker.draw(canvas, game(goal), step: 11)
    second = lit_ticker_pixels(canvas)
    expect(first).not_to be_empty
    expect(second.map { |x, y, rgb| [x + 1, y, rgb] }).to eq(first)
  end

  it "enters from the right edge of the ticker, so nothing shows before the first step" do
    ticker.draw(canvas, game(goal), step: 0)
    expect(lit_ticker_pixels(canvas)).to be_empty
    canvas.clear
    ticker.draw(canvas, game(goal), step: 10)
    expect(lit_ticker_pixels(canvas).map(&:first).min).to be >= 64
    expect(lit_ticker_pixels(canvas).map(&:first).max).to be <= 127
  end

  it "describes the goal by scorer, clock and period" do
    expect(ticker.text_for(goal(scorer: "MacKinnon", clock: "03:21", period: 2))).to eq("MacKinnon 03:21 P2")
  end
end
