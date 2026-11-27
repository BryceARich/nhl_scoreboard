# frozen_string_literal: true

require_relative "team_colors"

module NhlScoreboard
  # The goal ticker: one goal's text scrolling from right to left across a band of rows, in the
  # scoring team's colour (C1-05, ADR 0006, ADR 0007). Each row of boards has its own band, under
  # its boards, so the ticker takes the band's rectangle: its left column, its top row and its
  # width. The text enters at the band's right edge and leaves at its left, and the cycle repeats.
  #
  # Pixels outside the band's columns are cleared after drawing, so text never leaves the band.
  #
  # @example
  #   ticker = NhlScoreboard::GoalTicker.new(font)
  #   ticker.draw(canvas, goal, step: 12, x: 0, top: 24, width: 128)
  class GoalTicker
    # @return [Integer] the default band's first row, below a board's 24 rows.
    DEFAULT_TOP = 24
    # @return [Integer] the default band's height, in rows.
    DEFAULT_HEIGHT = 8

    # @return [BdfFont, Font] the font for the goal text.
    attr_reader :font

    # @return [Integer] the default band's first row.
    attr_reader :top

    # @return [Integer] the default band's height, in rows.
    attr_reader :height

    # @param font [BdfFont, Font] the font for the goal text.
    # @param top [Integer] the default band's first row.
    # @param height [Integer] the default band's height, in rows; the text is centred in it.
    # @return [GoalTicker]
    # @example
    #   NhlScoreboard::GoalTicker.new(NhlScoreboard::BdfFont.load("fonts/5x7.bdf"))
    def initialize(font, top: DEFAULT_TOP, height: DEFAULT_HEIGHT)
      @font = font
      @top = top
      @height = height
    end

    # Draws a goal's text in a band, scrolled by `step` columns, in the scoring team's colour. Draws
    # nothing for a nil goal. The canvas isn't cleared, so the caller clears it first.
    #
    # @param canvas [Canvas, FakeCanvas] the canvas to draw on.
    # @param goal [#tri_code, #scorer, #clock, #period, nil] the goal to show, or nil for none.
    # @param step [Integer] how many columns the text has scrolled; any integer, the cycle repeats.
    # @param x [Integer] the band's left column.
    # @param top [Integer] the band's first row.
    # @param width [Integer] the band's width in columns; defaults to the canvas's full width.
    # @return [nil]
    # @example
    #   ticker.draw(canvas, state.goals.last, step: 0, x: 0, top: 24, width: canvas.width)
    def draw(canvas, goal, step: 0, x: 0, top: @top, width: canvas.width)
      return nil unless goal

      text = text_for(goal)
      cycle = text_width(canvas, text, top) + width
      enter = x + width - (step % cycle)
      canvas.draw_text(font, enter, baseline(top), *TeamColors.rgb_for(goal.tri_code), text)
      clear_outside(canvas, x, width, top)
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

    # The baseline that centres the font's glyphs vertically in a band.
    #
    # @param band_top [Integer] the band's first row.
    # @return [Integer] the row of the baseline.
    def baseline(band_top)
      band_top + ((height - font.height) / 2) + font.baseline
    end

    # The width of the text in columns. It is drawn just past the canvas's right edge, where every
    # pixel is clipped, so nothing shows; the text's advance is what matters.
    #
    # @param canvas [Canvas, FakeCanvas] the canvas to measure on.
    # @param text [String] the text.
    # @param band_top [Integer] the band's first row, for the baseline.
    # @return [Integer] the width in columns.
    def text_width(canvas, text, band_top)
      canvas.draw_text(font, canvas.width, baseline(band_top), 0, 0, 0, text)
    end

    # Blacks out the band's rows to the left and right of its columns, so the text stays inside.
    # Only this band's rows are touched, and no other row's content lives in them.
    #
    # @param canvas [Canvas, FakeCanvas] the canvas.
    # @param x [Integer] the band's left column.
    # @param width [Integer] the band's width in columns.
    # @param band_top [Integer] the band's first row.
    # @return [void]
    def clear_outside(canvas, x, width, band_top)
      height.times do |dy|
        y = band_top + dy
        canvas.width.times do |col|
          next if col >= x && col < x + width

          canvas.set_pixel(col, y, 0, 0, 0)
        end
      end
    end
  end
end
