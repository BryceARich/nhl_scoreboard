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
  # Each goal is queued on its row's band once and scrolls across it once, from the right edge to the
  # left, in its team's colour, then is dropped (C1-10). Goals queue in the order they're scored, and
  # each waits until the one before it has left the band. A game's goals that are already there when
  # the game first appears are history: they aren't queued, unless +scroll_history+ says to replay them.
  #
  # Without a grid, the games sit side by side in one row, as they did before the grid existed.
  #
  # @example
  #   grid = NhlScoreboard::BoardGrid.for_canvas(width: 128, height: 32)
  #   display = NhlScoreboard::GameDisplay.new(matrix, layout, NhlScoreboard::LogoLibrary.load,
  #     ticker: NhlScoreboard::GoalTicker.new(font), grid: grid)
  #   display.show([home_game, away_game], step: 12)
  class GameDisplay
    # @return [Integer] the blank columns between two goals on the same band.
    GOAL_GAP = 8

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
    # @param scroll_history [Boolean] true to scroll a game's goals from before it first appeared,
    #   too; for a demo, where the goals are all history.
    # @return [GameDisplay]
    def initialize(matrix, layout, logos, ticker: nil, grid: nil, scroll_history: false)
      @matrix = matrix
      @layout = layout
      @logos = logos
      @ticker = ticker
      @grid = grid
      @scroll_history = scroll_history
      @known_games = Set.new
      @queued_goals = Set.new
      @queues = Hash.new { |hash, row| hash[row] = [] }
      @row_free_at = {}
    end

    # Draws the games on the offscreen canvas, each on its board, queues any goals scored since the
    # last call on their row's band, and draws each row's queued goals at their place, then swaps the
    # canvas onto the matrix.
    #
    # @param states [Array<GameState>, GameState] the games, first board first; one state is one board.
    # @param step [Integer] the scroll clock, in columns. The caller advances it, and it must never go back.
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

    # Queues new goals and draws each row's queue. A goal leaves its band's queue once its text has
    # left the band's left edge.
    #
    # @param canvas [Canvas, FakeCanvas] the canvas.
    # @param states [Array<GameState>] the games, board order.
    # @param layout_grid [BoardGrid] the grid.
    # @param step [Integer] the scroll step.
    # @return [void]
    def draw_tickers(canvas, states, layout_grid, step)
      layout_grid.rows.times do |row|
        band = layout_grid.ticker_band(row)
        layout_grid.boards_in_row(row).each do |index|
          queue_new_goals(canvas, row, band, states[index], step) if states[index]
        end
        queue = @queues[row]
        queue.reject! { |entry| step - entry[:start] >= entry[:span] }
        queue.each do |entry|
          ticker.draw_once(canvas, entry[:goal], step: step - entry[:start], x: band.x, top: band.top, width: band.width) if step >= entry[:start]
        end
      end
    end

    # Queues a game's goals that aren't queued yet. The first time a game appears its goals are
    # history, unless {#initialize}'s +scroll_history+ is set.
    #
    # @param canvas [Canvas, FakeCanvas] the canvas, to measure the goals' text on.
    # @param row [Integer] the row the game sits in.
    # @param band [#x, #top, #width] the row's band, from {BoardGrid#ticker_band}.
    # @param state [GameState] the game.
    # @param step [Integer] the scroll step the goal is queued at.
    # @return [void]
    def queue_new_goals(canvas, row, band, state, step)
      game = [state.home_team.tri_code, state.away_team.tri_code]
      new_game = @known_games.add?(game)
      state.goals.each do |goal|
        next unless @queued_goals.add?([game, goal.tri_code, goal.period, goal.clock, goal.scorer])
        next if new_game && !@scroll_history

        enqueue(canvas, row, band, goal, step)
      end
    end

    # Puts a goal at the end of its row's queue. It starts when the goal before it has cleared the
    # band, or now if the band is free.
    #
    # @param canvas [Canvas, FakeCanvas] the canvas, to measure the text on.
    # @param row [Integer] the row.
    # @param band [#x, #top, #width] the row's band.
    # @param goal [GameState::Goal] the goal.
    # @param step [Integer] the scroll step now.
    # @return [void]
    def enqueue(canvas, row, band, goal, step)
      span = ticker.span(canvas, goal, top: band.top, width: band.width)
      start = [step, @row_free_at.fetch(row, step)].max
      @queues[row] << {goal: goal, start: start, span: span}
      @row_free_at[row] = start + span + GOAL_GAP
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
