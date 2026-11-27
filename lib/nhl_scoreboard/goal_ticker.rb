# frozen_string_literal: true

require_relative "team_colors"

module NhlScoreboard
  # The goal ticker: one goal's text scrolling from right to left across the whole canvas, in the
  # scoring team's colour, in the band of rows under the boards (C1-05, ADR 0006). The text enters
  # at the right edge and leaves at the left, and the cycle then starts again. On a grid, the text
  # slides from one board into the next, because the band runs the full width of the canvas.
  #
  # The band is {DEFAULT_TOP} to {DEFAULT_TOP} + {DEFAULT_HEIGHT} - 1, below the boards' rows
  # (`ScoreboardLayout::BOARD_HEIGHT`), so the boards never draw over it.
  #
  # @example
  #   ticker = NhlScoreboard::GoalTicker.new(font)
  #   ticker.draw(canvas, goal, step: 12)
  class GoalTicker
    # @return [Integer] the band's first row, below the boards.
    DEFAULT_TOP = 24
    # @return [Integer] the band's height, in rows.
    DEFAULT_HEIGHT = 8

    # @return [BdfFont, Font] the font for the goal text.
    attr_reader :font

    # @return [Integer] the band's first row.
    attr_reader :top

    # @return [Integer] the band's height, in rows.
    attr_reader :height

    # @param font [BdfFont, Font] the font for the goal text.
    # @param top [Integer] the band's first row.
    # @param height [Integer] the band's height, in rows; the text is centred in it.
    # @return [GoalTicker]
    # @example
    #   NhlScoreboard::GoalTicker.new(NhlScoreboard::BdfFont.load("fonts/5x7.bdf"))
    def initialize(font, top: DEFAULT_TOP, height: DEFAULT_HEIGHT)
      @font = font
      @top = top
      @height = height
    end

    # Draws a goal's text in the band, shifted left by `step` columns, in the scoring team's colour.
    # Draws nothing for a nil goal. The canvas isn't cleared, so the caller clears it first.
    #
    # @param canvas [Canvas, FakeCanvas] the canvas to draw on; its width sets the scroll.
    # @param goal [#tri_code, #scorer, #clock, #period, nil] the goal to show, or nil for none.
    # @param step [Integer] how many columns the text has scrolled; any integer, the cycle repeats.
    # @return [nil]
    # @example
    #   ticker.draw(canvas, state.goals.last, step: 0) # the goal enters at the right edge
    def draw(canvas, goal, step: 0)
      return nil unless goal

      text = text_for(goal)
      cycle = text_width(canvas, text) + canvas.width
      x = canvas.width - (step % cycle)
      canvas.draw_text(font, x, baseline, *TeamColors.rgb_for(goal.tri_code), text)
      nil
    end

    # The text the ticker scrolls for one goal: who scored, when, and in which period.
    #
    # @param goal [#scorer, #clock, #period] the goal.
    # @return [String] for example "MacKinnon 03:21 P2".
    # @example
    #   ticker.text_for(goal) # => "MacKinnon 03:21 P2"
    def text_for(goal)
      "#{goal.scorer} #{goal.clock} P#{goal.period}"
    end

    private

    # The baseline that centres the font's glyphs vertically in the band.
    #
    # @return [Integer] the row of the baseline.
    def baseline
      top + ((height - font.height) / 2) + font.baseline
    end

    # The width of the text in columns. It is drawn just past the canvas's right edge, where every
    # pixel is clipped, so nothing shows; the text's advance is what matters.
    #
    # @param canvas [Canvas, FakeCanvas] the canvas to measure on.
    # @param text [String] the text.
    # @return [Integer] the width in columns.
    def text_width(canvas, text)
      canvas.draw_text(font, canvas.width, baseline, 0, 0, 0, text)
    end
  end
end
