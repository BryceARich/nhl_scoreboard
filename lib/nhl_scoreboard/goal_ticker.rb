# frozen_string_literal: true

require_relative "team_colors"
require_relative "team_names"

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

    # @return [String, nil] the favorite team's tri-code, upcased, or nil for none.
    attr_reader :favorite

    # @param font [BdfFont, Font] the font for the goal text.
    # @param top [Integer] the default band's first row.
    # @param height [Integer] the default band's height, in rows; the text is centred in it.
    # @param favorite [String, nil] the favorite team's tri-code. A goal by that team reads
    #   "{Team name} GOAL!!! scorer clock Pn"; nil or another team's goal reads "Goal (TRI) scorer clock Pn".
    # @return [GoalTicker]
    # @example
    #   NhlScoreboard::GoalTicker.new(NhlScoreboard::BdfFont.load("fonts/5x7.bdf"), favorite: "COL")
    def initialize(font, top: DEFAULT_TOP, height: DEFAULT_HEIGHT, favorite: nil)
      @font = font
      @top = top
      @height = height
      @favorite = favorite&.upcase
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

    # The number of steps a goal takes to scroll once across its band and out at the left edge: the
    # text's width plus the band's. {#draw_once} takes its steps from zero to here.
    #
    # @param canvas [Canvas, FakeCanvas] the canvas to measure on.
    # @param goal [#tri_code, #scorer, #clock, #period] the goal.
    # @param top [Integer] the band's first row.
    # @param width [Integer] the band's width in columns.
    # @return [Integer] the steps from the right edge until the text has left the band.
    # @example
    #   ticker.span(canvas, goal, top: 24, width: 64) # => 214
    def span(canvas, goal, top: @top, width: canvas.width)
      advance(canvas, goal, top: top) + width
    end

    # The width of a goal's text in columns: how far it moves from the moment its first column enters
    # until its last column has passed the right edge.
    #
    # @param canvas [Canvas, FakeCanvas] the canvas to measure on.
    # @param goal [#tri_code, #scorer, #clock, #period] the goal.
    # @param top [Integer] the band's first row, for the baseline.
    # @return [Integer] the text's width in columns.
    # @example
    #   ticker.advance(canvas, goal) # => 150
    def advance(canvas, goal, top: @top)
      text_width(canvas, text_for(goal), top)
    end

    # The blank columns between two goals' text, the width of a space in the font.
    #
    # @return [Integer] the space's advance, or 3 when the font has no space.
    # @example
    #   ticker.gap_width # => 4
    def gap_width
      font.glyph(" ".ord)&.advance || 3
    end

    # Draws a goal once, scrolling it from the band's right edge at step 0 to its left. Draws nothing
    # before step 0 or once the text has left the band, so the caller can drop the goal then. Like
    # {#draw}, the canvas isn't cleared.
    #
    # @param canvas [Canvas, FakeCanvas] the canvas to draw on.
    # @param goal [#tri_code, #scorer, #clock, #period, nil] the goal, or nil for none.
    # @param step [Integer] how many columns the text has scrolled since it entered.
    # @param x [Integer] the band's left column.
    # @param top [Integer] the band's first row.
    # @param width [Integer] the band's width in columns.
    # @return [nil]
    # @example
    #   ticker.draw_once(canvas, goal, step: 0, x: 0, top: 24, width: 64)
    def draw_once(canvas, goal, step:, x: 0, top: @top, width: canvas.width)
      return nil unless goal && step >= 0 && step < span(canvas, goal, top: top, width: width)

      canvas.draw_text(font, x + width - step, baseline(top), *TeamColors.rgb_for(goal.tri_code), text_for(goal))
      clear_outside(canvas, x, width, top)
      nil
    end

    # The text the ticker scrolls for one goal: the team and scorer, when, and in which period. A goal
    # by the favorite team reads as a shout instead.
    #
    # @param goal [#tri_code, #scorer, #clock, #period] the goal.
    # @return [String] for example "Goal (CHI) MacKinnon 03:21 P2", or "AVALANCHE GOAL!!! MacKinnon 03:21 P2" for the
    #   favorite.
    # @example
    #   ticker.text_for(goal) # => "Goal (COL) MacKinnon 03:21 P2"
    def text_for(goal)
      return "#{TeamNames.name_for(goal.tri_code).upcase} GOAL!!! #{goal.scorer} #{goal.clock} P#{goal.period}" if favorite_goal?(goal)

      "Goal (#{goal.tri_code}) #{goal.scorer} #{goal.clock} P#{goal.period}"
    end

    private

    # @param goal [#tri_code] the goal.
    # @return [Boolean] true when the favorite team scored it.
    def favorite_goal?(goal)
      !favorite.nil? && goal.tri_code.to_s.upcase == favorite
    end

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
