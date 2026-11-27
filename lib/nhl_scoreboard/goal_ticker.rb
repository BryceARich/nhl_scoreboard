# frozen_string_literal: true

require_relative "team_colors"

module NhlScoreboard
  # The right 64 columns of the panel: the latest goal, scrolling from right to left in the scoring
  # team's colours (C1-05). Each step moves the text one column, and once it has gone off the left
  # edge the cycle starts again.
  #
  # The text can run past column 64 into the logo area. {GameDisplay} draws the ticker before the
  # {ScoreboardLayout}, which clears the left 64 columns again, so the overflow never shows.
  #
  # The game is anything that answers `goals`, a list whose last item answers `tri_code`, `period`,
  # `clock` and `scorer` (ADR 0006). A game with no goals draws nothing.
  #
  # @example
  #   ticker = NhlScoreboard::GoalTicker.new(font)
  #   ticker.draw(canvas, state, step: 12)
  class GoalTicker
    # @return [Integer] the first column of the ticker.
    X = 64
    # @return [Integer] the ticker's width in columns; the text enters from the right edge.
    WIDTH = 64
    # @return [Integer] the panel's height, for centring the text vertically.
    HEIGHT = 32

    # @return [BdfFont, Font] the font for the goal text.
    attr_reader :font

    # @param font [BdfFont, Font] the font for the goal text.
    # @return [GoalTicker]
    # @example
    #   NhlScoreboard::GoalTicker.new(NhlScoreboard::BdfFont.load("fonts/5x7.bdf"))
    def initialize(font)
      @font = font
    end

    # Draws the latest goal, shifted left by `step` columns, in the scoring team's colour. Draws
    # nothing when the game has no goals. The canvas isn't cleared, so the caller clears it first.
    #
    # @param canvas [Canvas, FakeCanvas] the canvas to draw on.
    # @param game [#goals] the game; its last goal is the one shown.
    # @param step [Integer] how many columns the text has scrolled; any integer, the cycle repeats.
    # @return [nil]
    # @example
    #   ticker.draw(canvas, state, step: 0) # the goal enters at column 127
    def draw(canvas, game, step: 0)
      goal = game.goals.last
      return nil unless goal

      text = text_for(goal)
      cycle = text_width(canvas, text) + WIDTH
      x = X + WIDTH - (step % cycle)
      canvas.draw_text(font, x, baseline, *TeamColors.rgb_for(goal.tri_code), text)
      nil
    end

    # The text the ticker scrolls for one goal: who scored, when, and in which period.
    #
    # @param goal [#scorer, #clock, #period] the goal.
    # @return [String] for example "Demo scorer 12:34 P1".
    # @example
    #   ticker.text_for(goal) # => "MacKinnon 03:21 P2"
    def text_for(goal)
      "#{goal.scorer} #{goal.clock} P#{goal.period}"
    end

    private

    # The baseline that centres the font's glyphs vertically on the panel.
    #
    # @return [Integer] the row of the baseline.
    def baseline
      ((HEIGHT - font.height) / 2) + font.baseline
    end

    # The width of the text in columns. It is drawn just past the canvas's right edge, where
    # every pixel is clipped, so nothing shows; the text's advance is what matters.
    #
    # @param canvas [Canvas, FakeCanvas] the canvas to measure on.
    # @param text [String] the text.
    # @return [Integer] the width in columns.
    def text_width(canvas, text)
      canvas.draw_text(font, X + WIDTH, baseline, 0, 0, 0, text)
    end
  end
end
