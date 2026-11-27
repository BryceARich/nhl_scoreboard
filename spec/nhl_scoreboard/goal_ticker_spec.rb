# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::GoalTicker do
  let(:font) { NhlScoreboard::BdfFont.load(File.expand_path("../fixtures/tiny.bdf", __dir__)) }
  let(:ticker) { described_class.new(font) }
  let(:canvas) { NhlScoreboard::FakeCanvas.new(width: 128, height: 32) }

  def goal(tri_code: "COL", scorer: "ILL", clock: "12:34", period: 1)
    NhlScoreboard::GameState::Goal.new(tri_code: tri_code, period: period, clock: clock, scorer: scorer)
  end

  # Every lit pixel on the canvas, as [x, y, rgb].
  def lit_pixels(canvas)
    (0...canvas.width).flat_map do |x|
      (0...canvas.height).filter_map do |y|
        rgb = canvas.pixel(x, y)
        [x, y, rgb] if rgb.any?(&:positive?)
      end
    end
  end

  it "draws nothing for a nil goal" do
    ticker.draw(canvas, nil, step: 10)
    expect(lit_pixels(canvas)).to be_empty
  end

  it "keeps the text inside the band below the boards" do
    ticker.draw(canvas, goal, step: 10)
    rows = lit_pixels(canvas).map { |_, y, _| y }
    expect(rows.min).to be >= NhlScoreboard::GoalTicker::DEFAULT_TOP
    expect(rows.max).to be < NhlScoreboard::GoalTicker::DEFAULT_TOP + NhlScoreboard::GoalTicker::DEFAULT_HEIGHT
  end

  it "draws the goal in the scoring team's colour" do
    ticker.draw(canvas, goal(tri_code: "CHI"), step: 10)
    colours = lit_pixels(canvas).map(&:last).uniq
    expect(colours).to eq([NhlScoreboard::TeamColors.rgb_for("CHI")])
  end

  it "enters from the right edge, so nothing shows before the first step" do
    ticker.draw(canvas, goal, step: 0)
    expect(lit_pixels(canvas)).to be_empty
  end

  it "scrolls one column per step" do
    ticker.draw(canvas, goal, step: 10)
    first = lit_pixels(canvas)
    canvas.clear
    ticker.draw(canvas, goal, step: 11)
    second = lit_pixels(canvas)
    expect(first).not_to be_empty
    expect(second.map { |x, y, rgb| [x + 1, y, rgb] }).to eq(first)
  end

  it "runs the text across the whole canvas width, so it can cross a board edge" do
    ticker.draw(canvas, goal, step: 10)
    expect(lit_pixels(canvas).map(&:first).max).to be <= 127
    canvas.clear
    ticker.draw(canvas, goal, step: 70)
    expect(lit_pixels(canvas).map(&:first).min).to be < 64
  end

  it "describes the goal by scorer, clock and period" do
    expect(ticker.text_for(goal(scorer: "MacKinnon", clock: "03:21", period: 2))).to eq("MacKinnon 03:21 P2")
  end
end
