# frozen_string_literal: true

require_relative "scoreboard_layout"
require_relative "team_logos"

module NhlScoreboard
  # Shows one or more {GameState}s on a matrix: one 64-column board per game, left to right, with
  # the goal ticker in the band under them. It picks each team's logo, lays the frame out, and swaps
  # it in. The fake panels and the main loop both draw through it, so a demo and a live game look
  # the same.
  #
  # @example
  #   display = NhlScoreboard::GameDisplay.new(matrix, layout, NhlScoreboard::LogoLibrary.load, ticker: ticker)
  #   display.show([home_game, away_game], step: 12)
  class GameDisplay
    # @return [Matrix, FakeMatrix] the matrix to draw on.
    attr_reader :matrix

    # @return [ScoreboardLayout] the layout that draws each board.
    attr_reader :layout

    # @return [Hash{String => PpmImage}] the logos by name, as {LogoLibrary.load} returns them.
    attr_reader :logos

    # @return [GoalTicker, nil] the ticker for the band under the boards, or nil for none.
    attr_reader :ticker

    # @param matrix [Matrix, FakeMatrix] the matrix to draw on.
    # @param layout [ScoreboardLayout] the layout, built with a font.
    # @param logos [Hash{String => PpmImage}] the logos by name.
    # @param ticker [GoalTicker, nil] the goal ticker; nil draws the boards with no band.
    # @return [GameDisplay]
    def initialize(matrix, layout, logos, ticker: nil)
      @matrix = matrix
      @layout = layout
      @logos = logos
      @ticker = ticker
    end

    # Draws the games on the offscreen canvas, one board each from the left, with the ticker's
    # latest goal across the band, then swaps the canvas onto the matrix. The ticker shows the last
    # goal listed across all the games, in board order.
    #
    # @param states [Array<GameState>, GameState] the games, one per board; a single state is one board.
    # @param step [Integer] how far the goal ticker has scrolled; the caller advances it.
    # @return [Canvas, FakeCanvas] the canvas now showing.
    # @example
    #   display.show(NhlScoreboard::GameState.load("assets/demo_game.json"), step: 4)
    def show(states, step: 0)
      states = [states] unless states.is_a?(Array)
      canvas = matrix.offscreen_canvas
      canvas.fill(0, 0, 0)
      ticker&.draw(canvas, latest_goal(states), step: step)
      states.each_with_index do |state, index|
        layout.draw(canvas, state, home_logo: logo_for(state.home_team), away_logo: logo_for(state.away_team),
          x: index * ScoreboardLayout::BOARD_WIDTH)
      end
      matrix.swap_on_vsync(canvas)
      matrix.canvas
    end

    private

    # The last goal listed across the games, in board order, or nil when none has one.
    #
    # @param states [Array<GameState>] the games.
    # @return [GameState::Goal, nil]
    def latest_goal(states)
      states.flat_map { |state| state.respond_to?(:goals) ? state.goals : [] }.last
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
