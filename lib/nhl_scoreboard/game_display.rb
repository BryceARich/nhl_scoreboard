# frozen_string_literal: true

require_relative "team_logos"

module NhlScoreboard
  # Shows any {GameState} on a matrix: picks each team's logo, lays the frame out, and swaps it in.
  # The fake panels and the main loop both draw through it, so a demo and a live game look the same.
  #
  # @example
  #   display = NhlScoreboard::GameDisplay.new(matrix, layout, NhlScoreboard::LogoLibrary.load)
  #   display.show(state)
  class GameDisplay
    # @return [Matrix, FakeMatrix] the matrix to draw on.
    attr_reader :matrix

    # @return [ScoreboardLayout] the layout that draws the frame.
    attr_reader :layout

    # @return [Hash{String => PpmImage}] the logos by name, as {LogoLibrary.load} returns them.
    attr_reader :logos

    # @param matrix [Matrix, FakeMatrix] the matrix to draw on.
    # @param layout [ScoreboardLayout] the layout, built with a font.
    # @param logos [Hash{String => PpmImage}] the logos by name.
    # @return [GameDisplay]
    def initialize(matrix, layout, logos)
      @matrix = matrix
      @layout = layout
      @logos = logos
    end

    # Draws a state on the offscreen canvas, then swaps it onto the matrix.
    #
    # @param state [GameState, #phase, #period, #period_type, #clock, #home_team, #away_team] the state to show.
    # @return [Canvas, FakeCanvas] the canvas now showing.
    # @example
    #   display.show(NhlScoreboard::GameState.load("assets/demo_game.json"))
    def show(state)
      canvas = matrix.offscreen_canvas
      layout.draw(canvas, state, home_logo: logo_for(state.home_team), away_logo: logo_for(state.away_team))
      matrix.swap_on_vsync(canvas)
      matrix.canvas
    end

    private

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
