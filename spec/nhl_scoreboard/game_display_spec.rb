# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::GameDisplay do
  let(:matrix) { NhlScoreboard::FakeMatrix.new(NhlScoreboard::MatrixSettings.new(rows: 32, cols: 64, chain_length: 1)) }
  let(:font) { NhlScoreboard::BdfFont.load(File.expand_path("../fixtures/tiny.bdf", __dir__)) }
  let(:logos) { NhlScoreboard::LogoLibrary.load }
  let(:display) { described_class.new(matrix, NhlScoreboard::ScoreboardLayout.new(font), logos) }

  def state(home:, away:)
    NhlScoreboard::GameState.new(
      phase: :regulation, period: 1, period_type: :regulation, clock: "12:34",
      home_team: NhlScoreboard::GameState::Team.new(tri_code: home, score: 1),
      away_team: NhlScoreboard::GameState::Team.new(tri_code: away, score: 0),
      goals: []
    )
  end

  it "shows the state on the matrix, with each team's logo in its slot" do
    shown = display.show(state(home: "COL", away: "CHI"))
    expect(shown.pixel(0, 2)).to eq(logos.fetch("avalanche").pixel(0, 0))
    expect(shown.pixel(44, 2)).to eq(logos.fetch("blackhawks").pixel(0, 0))
  end

  it "shows a different state with a different logo, from the same display" do
    display.show(state(home: "COL", away: "CHI"))
    shown = display.show(state(home: "VGK", away: "CHI"))
    expect(shown.pixel(0, 2)).to eq(logos.fetch("goldenknights").pixel(0, 0))
  end

  it "draws the goal ticker in the band under the boards" do
    ticker = NhlScoreboard::GoalTicker.new(font)
    goal = NhlScoreboard::GameState::Goal.new(tri_code: "CHI", period: 1, clock: "12:34", scorer: "ILL")
    wide = NhlScoreboard::FakeMatrix.new(NhlScoreboard::MatrixSettings.new(rows: 32, cols: 64, chain_length: 2))
    grid = NhlScoreboard::BoardGrid.new(boards: 2, columns: 2)
    shown_display = described_class.new(wide, NhlScoreboard::ScoreboardLayout.new(font), logos, ticker: ticker, grid: grid, scroll_history: true)
    lit = state(home: "COL", away: "CHI").with(goals: [goal])
    shown_display.show(lit, step: 10) # the goal is queued at step 10
    shown = shown_display.show(lit, step: 50) # and has scrolled 40 columns in by step 50
    colour = NhlScoreboard::TeamColors.rgb_for("CHI")
    right = (64...128).flat_map { |x| (0...32).map { |y| shown.pixel(x, y) } }
    expect(right).to include(colour)
    expect(shown.pixel(0, 2)).to eq(logos.fetch("avalanche").pixel(0, 0))
  end

  it "lays a second game out on the next board, 64 columns to the right" do
    wide = NhlScoreboard::FakeMatrix.new(NhlScoreboard::MatrixSettings.new(rows: 32, cols: 64, chain_length: 2))
    two = described_class.new(wide, NhlScoreboard::ScoreboardLayout.new(font), logos)
    shown = two.show([state(home: "COL", away: "CHI"), state(home: "VGK", away: "CHI")])
    expect(shown.pixel(0, 2)).to eq(logos.fetch("avalanche").pixel(0, 0))
    expect(shown.pixel(64, 2)).to eq(logos.fetch("goldenknights").pixel(0, 0))
  end

  it "draws a placeholder for a team code that has no logo" do
    shown = display.show(state(home: "XYZ", away: "CHI"))
    expect(shown.pixel(0, 2)).to eq([90, 90, 90])
  end

  it "gives each row of boards its own ticker, from that row's games only" do
    ticker = NhlScoreboard::GoalTicker.new(font)
    grid = NhlScoreboard::BoardGrid.new(boards: 3, columns: 2)
    tall = NhlScoreboard::FakeMatrix.new(NhlScoreboard::MatrixSettings.new(rows: 64, cols: 64, chain_length: 2))
    goal = NhlScoreboard::GameState::Goal.new(tri_code: "CHI", period: 1, clock: "12:34", scorer: "ILL")
    games = [state(home: "COL", away: "CHI"), state(home: "VGK", away: "CHI"), state(home: "TOR", away: "BOS")]
    display = described_class.new(tall, NhlScoreboard::ScoreboardLayout.new(font), logos, ticker: ticker, grid: grid, scroll_history: true)
    display.show(games, step: 20)
    games[2] = games[2].with(goals: [goal])
    display.show(games, step: 20) # the goal is queued here, at step 20
    shown = display.show(games, step: 60) # so at step 60 it has scrolled 40 columns in
    top_band = (0...128).flat_map { |x| (24...32).map { |y| shown.pixel(x, y) } }
    bottom_band = (0...64).flat_map { |x| (56...64).map { |y| shown.pixel(x, y) } }
    expect(top_band.uniq).to eq([[0, 0, 0]])
    expect(bottom_band).to include(NhlScoreboard::TeamColors.rgb_for("CHI"))
  end

  it "keeps a short row's ticker to that row, so text never reaches the empty cells" do
    ticker = NhlScoreboard::GoalTicker.new(font)
    grid = NhlScoreboard::BoardGrid.new(boards: 3, columns: 2)
    tall = NhlScoreboard::FakeMatrix.new(NhlScoreboard::MatrixSettings.new(rows: 64, cols: 64, chain_length: 2))
    goal = NhlScoreboard::GameState::Goal.new(tri_code: "CHI", period: 1, clock: "12:34", scorer: "ILL")
    lone = state(home: "TOR", away: "BOS")
    display = described_class.new(tall, NhlScoreboard::ScoreboardLayout.new(font), logos, ticker: ticker, grid: grid, scroll_history: true)
    games = [state(home: "COL", away: "CHI"), state(home: "VGK", away: "CHI"), lone]
    display.show(games, step: 0)
    games[2] = lone.with(goals: [goal])
    (0..200).step(10).each do |step|
      shown = display.show(games, step: step)
      empty_cells = (64...128).flat_map { |x| (56...64).map { |y| shown.pixel(x, y) } }
      expect(empty_cells.uniq).to eq([[0, 0, 0]])
    end
  end

  describe "the goal queue (C1-10)" do
    let(:ticker) { NhlScoreboard::GoalTicker.new(font) }
    let(:wide_matrix) { NhlScoreboard::FakeMatrix.new(NhlScoreboard::MatrixSettings.new(rows: 32, cols: 64, chain_length: 2)) }
    let(:grid) { NhlScoreboard::BoardGrid.new(boards: 2, columns: 2) }
    let(:chi_goal) { NhlScoreboard::GameState::Goal.new(tri_code: "CHI", period: 1, clock: "12:34", scorer: "ILL") }
    let(:col_goal) { NhlScoreboard::GameState::Goal.new(tri_code: "COL", period: 2, clock: "03:00", scorer: "Rantanen") }
    let(:plain) { state(home: "COL", away: "CHI") }

    def queue_display
      described_class.new(wide_matrix, NhlScoreboard::ScoreboardLayout.new(font), logos, ticker: ticker, grid: grid)
    end

    # Every colour lit in the band under the boards, across the top row of the canvas.
    def band_colours(shown)
      (0...128).flat_map { |x| (24...32).map { |y| shown.pixel(x, y) } }.uniq
    end

    it "doesn't scroll goals a game already had when it first appeared" do
      display = queue_display
      display.show(plain.with(goals: [chi_goal]), step: 0)
      expect(band_colours(display.show(plain.with(goals: [chi_goal]), step: 30))).to eq([[0, 0, 0]])
    end

    it "scrolls a goal scored later once, then drops it after it has left the band" do
      display = queue_display
      display.show(plain, step: 0)
      display.show(plain.with(goals: [chi_goal]), step: 0)
      expect(band_colours(display.show(plain.with(goals: [chi_goal]), step: 20))).to include(NhlScoreboard::TeamColors.rgb_for("CHI"))
      expect(band_colours(display.show(plain.with(goals: [chi_goal]), step: 1000))).to eq([[0, 0, 0]])
    end

    it "starts the next goal without waiting for the last one to leave, each in its own team's colour" do
      display = queue_display
      display.show(plain, step: 0)
      both = plain.with(goals: [chi_goal, col_goal])
      display.show(both, step: 0)
      colours = band_colours(display.show(both, step: 20))
      expect(colours).to include(NhlScoreboard::TeamColors.rgb_for("CHI"), NhlScoreboard::TeamColors.rgb_for("COL"))
    end
  end

  it "fails clearly when there are more games than boards" do
    grid = NhlScoreboard::BoardGrid.new(boards: 1, columns: 1)
    expect { described_class.new(matrix, NhlScoreboard::ScoreboardLayout.new(font), logos, grid: grid).show([state(home: "COL", away: "CHI"), state(home: "VGK", away: "CHI")]) }
      .to raise_error(ArgumentError, /2 games don't fit 1 boards/)
  end

  it "fails clearly when the grid is bigger than the panels" do
    grid = NhlScoreboard::BoardGrid.new(boards: 7, columns: 4)
    expect { described_class.new(matrix, NhlScoreboard::ScoreboardLayout.new(font), logos, grid: grid).show([state(home: "COL", away: "CHI")]) }
      .to raise_error(ArgumentError, /doesn't fit/)
  end
end
