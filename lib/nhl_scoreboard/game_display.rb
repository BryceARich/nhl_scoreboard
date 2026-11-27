# frozen_string_literal: true

require_relative "board_grid"
require_relative "scoreboard_layout"
require_relative "team_logos"

module NhlScoreboard
  # Shows games on a matrix (ADR 0007): each game on its board in a {BoardGrid}, with each row of
  # boards getting its own goal ticker under it. It picks each team's logo, lays the frame out, and
  # swaps it in. The fake panels and the main loop both draw through it, so a demo and a live game
  # look the same.
  #
  # Without a grid, the games sit side by side in one row, as they did before the grid existed.
  #
  # @example
  #   grid = NhlScoreboard::BoardGrid.for_canvas(width: 128, height: 32)
  #   display = NhlScoreboard::GameDisplay.new(matrix, layout, NhlScoreboard::LogoLibrary.load,
  #     ticker: NhlScoreboard::GoalTicker.new(font), grid: grid)
  #   display.show([home_game, away_game], step: 12)
  class GameDisplay
    # @return [Matrix, FakeMatrix] the matrix to draw on.
    attr_reader :matrix

    # @return [ScoreboardLayout] the layout that draws each board.
    attr_reader :layout

    # @return [Hash{String => PpmImage}] the logos by name, as {LogoLibrary.load} returns them.
    attr_reader :logos

    # @return [GoalTicker, nil] the ticker for each row's band, or nil for none.
    attr_reader :ticker

    # @return [BoardGrid, nil] where the boards sit, or nil to lay the games out in one row.
    attr_reader :grid

    # @param matrix [Matrix, FakeMatrix] the matrix to draw on.
    # @param layout [ScoreboardLayout] the layout, built with a font.
    # @param logos [Hash{String => PpmImage}] the logos by name.
    # @param ticker [GoalTicker, nil] the goal ticker; nil draws the boards with no bands.
    # @param grid [BoardGrid, nil] the board grid; nil lays the games out side by side.
    # @return [GameDisplay]
    def initialize(matrix, layout, logos, ticker: nil, grid: nil)
      @matrix = matrix
      @layout = layout
      @logos = logos
      @ticker = ticker
      @grid = grid
    end

    # Draws the games on the offscreen canvas, each on its board, with each row's ticker showing that
    # row's latest goal, then swaps the canvas onto the matrix.
    #
    # @param states [Array<GameState>, GameState] the games, first board first; one state is one board.
    # @param step [Integer] how far the goal tickers have scrolled; the caller advances it.
    # @return [Canvas, FakeCanvas] the canvas now showing.
    # @raise [ArgumentError] if there are more games than the grid has boards, or the grid is bigger than the canvas.
    # @example
    #   display.show(NhlScoreboard::GameState.load("assets/demo_game.json"), step: 4)
    def show(states, step: 0)
      states = [states] unless states.is_a?(Array)
      layout_grid = grid || BoardGrid.new(boards: [states.size, 1].max, columns: [states.size, 1].max)
      check_fit!(layout_grid, states)
      canvas = matrix.offscreen_canvas
      canvas.fill(0, 0, 0)
      states.each_with_index do |state, index|
        x, y = layout_grid.origin(index)
        layout.draw(canvas, state, home_logo: logo_for(state.home_team), away_logo: logo_for(state.away_team), x: x, y: y)
      end
      draw_tickers(canvas, states, layout_grid, step) if ticker
      matrix.swap_on_vsync(canvas)
      matrix.canvas
    end

    private

    # Draws each row's ticker from that row's boards only. A row with no games gets no text.
    #
    # @param canvas [Canvas, FakeCanvas] the canvas.
    # @param states [Array<GameState>] the games, board order.
    # @param layout_grid [BoardGrid] the grid.
    # @param step [Integer] the scroll step.
    # @return [void]
    def draw_tickers(canvas, states, layout_grid, step)
      layout_grid.rows.times do |row|
        row_states = layout_grid.boards_in_row(row).filter_map { |index| states[index] }
        next if row_states.empty?

        band = layout_grid.ticker_band(row)
        ticker.draw(canvas, latest_goal(row_states), step: step, x: band.x, top: band.top, width: band.width)
      end
    end

    # The last goal listed across some games, in board order, or nil when none has one.
    #
    # @param states [Array<GameState>] the games.
    # @return [GameState::Goal, nil]
    def latest_goal(states)
      states.flat_map { |state| state.respond_to?(:goals) ? state.goals : [] }.last
    end

    # @param layout_grid [BoardGrid] the grid the boards sit in.
    # @param states [Array<GameState>] the games to show.
    # @return [void]
    # @raise [ArgumentError] if the games outnumber the boards, or the grid is bigger than the canvas.
    def check_fit!(layout_grid, states)
      raise ArgumentError, "#{states.size} games don't fit #{layout_grid.boards} boards" if states.size > layout_grid.boards

      canvas = matrix.offscreen_canvas
      return if layout_grid.width <= canvas.width && layout_grid.height <= canvas.height

      raise ArgumentError, "a #{layout_grid.width}x#{layout_grid.height} grid doesn't fit the #{canvas.width}x#{canvas.height} panels"
    end

    # The logo for a team, or nil for a team with no logo, which the layout draws as a placeholder.
    #
    # @param team [GameState::Team] the team.
    # @return [PpmImage, nil]
    def logo_for(team)
      name = TeamLogos.name_for(team.tri_code)
      name && logos[name]
    end
  end
end
