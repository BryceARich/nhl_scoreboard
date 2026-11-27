# frozen_string_literal: true

module NhlScoreboard
  # Draws one board's scoreboard from one game's state: the two team logos, the period, the clock
  # and the score, at the positions of the old `led_scoreboard.py` (C1-04). A board is 64 columns
  # wide and 24 rows high; the goal ticker has the rows below it (ADR 0006). It draws onto a canvas
  # and doesn't swap; the caller swaps, as the main loop does.
  #
  # The game is a `SportsIngest::NHL::GameScore`, or anything that answers the same methods. This
  # reads `phase`, `period`, `period_type`, `clock`, and `home_team` and `away_team` with `score`
  # (ADR 0005). It doesn't require the gem, so the Pi installs nothing new.
  #
  # @example
  #   layout = NhlScoreboard::ScoreboardLayout.new(font)
  #   layout.draw(canvas, game, home_logo: logos["avalanche"], away_logo: logos["kraken"], x: 64)
  #   matrix.swap_on_vsync(canvas)
  class ScoreboardLayout
    # @return [Integer] the width of one board, in columns.
    BOARD_WIDTH = 64
    # @return [Integer] the height of one board's scoreboard, in rows; the ticker band starts below.
    BOARD_HEIGHT = 24
    # @return [Integer] the column of the home logo's left edge, from the board's left edge.
    HOME_LOGO_X = 0
    # @return [Integer] the column of the away logo's left edge, from the board's left edge.
    AWAY_LOGO_X = 44
    # @return [Integer] the row of both logos' top edge.
    LOGO_Y = 2
    # @return [Integer] the logo box's width and height.
    LOGO_SIZE = 20
    # @return [Integer] the column the period and the score start at, from the board's left edge.
    TEXT_X = 24
    # @return [Integer] the column the clock starts at, 5 left of {TEXT_X}.
    CLOCK_X = 19
    # @return [Integer] the baseline of the period text.
    ORDINAL_Y = 6
    # @return [Integer] the baseline of the clock.
    CLOCK_Y = 13
    # @return [Integer] the baseline of the score.
    SCORE_Y = 20
    # @return [Array<Integer>] the colour of all the text, `[r, g, b]`.
    TEXT_COLOR = [255, 255, 255].freeze
    # @return [Hash{Integer => String}] the first three periods' ordinals; later ones use {#ordinal}.
    PERIOD_ORDINALS = {1 => "1ST", 2 => "2ND", 3 => "3RD"}.freeze

    # @return [BdfFont, Font] the font for the period, clock and score.
    attr_reader :font

    # @param font [BdfFont, Font] a font with the characters `0-9`, `:`, `-` and the period text.
    # @return [ScoreboardLayout]
    # @example
    #   NhlScoreboard::ScoreboardLayout.new(NhlScoreboard::BdfFont.load("fonts/5x7.bdf"))
    def initialize(font)
      @font = font
    end

    # Clears this board's 64 × 24 area to black, then draws one game's frame onto it. The rows
    # below the board, the ticker band, are left alone. An empty logo slot is a grey placeholder
    # box.
    #
    # @param canvas [Canvas, FakeCanvas] the canvas to draw on.
    # @param game [#phase, #period, #period_type, #clock, #home_team, #away_team] the game's state.
    # @param home_logo [PpmImage, nil] the home team's logo, drawn in the left slot.
    # @param away_logo [PpmImage, nil] the away team's logo, drawn in the right slot.
    # @param x [Integer] the board's left column on the canvas; 0 for the first board.
    # @return [nil]
    # @example
    #   layout.draw(canvas, game, home_logo: home, away_logo: nil, x: 64)
    def draw(canvas, game, home_logo: nil, away_logo: nil, x: 0)
      clear_board(canvas, x)
      draw_logo(canvas, x + HOME_LOGO_X, home_logo)
      draw_logo(canvas, x + AWAY_LOGO_X, away_logo)
      canvas.draw_text(font, x + TEXT_X, ORDINAL_Y, *TEXT_COLOR, ordinal(game))
      canvas.draw_text(font, x + CLOCK_X, CLOCK_Y, *TEXT_COLOR, clock_text(game))
      canvas.draw_text(font, x + TEXT_X, SCORE_Y, *TEXT_COLOR, score_text(game))
      nil
    end

    private

    # Clears one board's area, one pixel at a time, since the canvas can't clear part of itself.
    #
    # @param canvas [Canvas, FakeCanvas] the canvas to clear.
    # @param x [Integer] the board's left column.
    # @return [void]
    def clear_board(canvas, x)
      BOARD_HEIGHT.times do |y|
        BOARD_WIDTH.times { |dx| canvas.set_pixel(x + dx, y, 0, 0, 0) }
      end
    end

    # The period text: the period's ordinal in regulation, `OT` or `SO` in extra time, `INT` between
    # periods, `FINAL` at the end, and blank before the game starts.
    #
    # @param game [#phase, #period] the game's state.
    # @return [String]
    def ordinal(game)
      case game.phase
      when :regulation then PERIOD_ORDINALS.fetch(game.period, "")
      when :overtime then "OT"
      when :shootout then "SO"
      when :intermission then "INT"
      when :final then "FINAL"
      else ""
      end
    end

    # The clock text: the time left in the period. After a game that went to extra time, the
    # clock slot shows `OT` or `SO` instead, and before the game starts it is blank.
    #
    # @param game [#phase, #period_type, #clock] the game's state.
    # @return [String]
    def clock_text(game)
      return extra_time_text(game) if game.phase == :final

      game.clock || ""
    end

    # @param game [#period_type] a finished game.
    # @return [String] `OT`, `SO`, or blank for a game decided in regulation.
    def extra_time_text(game)
      case game.period_type
      when :overtime then "OT"
      when :shootout then "SO"
      else ""
      end
    end

    # The score as `home-away`, as the old layout showed it, or blank until both sides have one.
    #
    # @param game [#home_team, #away_team] the game's state.
    # @return [String] for example "3-2".
    def score_text(game)
      home = game.home_team.score
      away = game.away_team.score
      return "" if home.nil? || away.nil?

      "#{home}-#{away}"
    end

    # Draws a team's logo, or a grey placeholder box in its slot when there is no logo.
    #
    # @param canvas [Canvas, FakeCanvas] the canvas to draw on.
    # @param x [Integer] the slot's left column on the canvas.
    # @param logo [PpmImage, nil] the logo, or nil for the placeholder.
    # @return [void]
    def draw_logo(canvas, x, logo)
      return logo.draw(canvas, x, LOGO_Y) if logo

      LOGO_SIZE.times do |dy|
        LOGO_SIZE.times do |dx|
          edge = dx.zero? || dy.zero? || dx == LOGO_SIZE - 1 || dy == LOGO_SIZE - 1
          canvas.set_pixel(x + dx, LOGO_Y + dy, *(edge ? [90, 90, 90] : [30, 30, 30]))
        end
      end
    end
  end
end
