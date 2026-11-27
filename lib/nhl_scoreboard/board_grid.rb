# frozen_string_literal: true

require_relative "goal_ticker"
require_relative "scoreboard_layout"

module NhlScoreboard
  # Where each board sits on the canvas (ADR 0007). Boards fill the grid row by row, +columns+ to a
  # row, so a short last row leaves its right-hand cells empty. Each row of boards has its own goal
  # ticker band underneath, sized to the boards in that row.
  #
  # A board is 64 columns by {ScoreboardLayout::BOARD_HEIGHT} rows. A row is a board's height plus
  # the ticker band, {ROW_HEIGHT} rows in all, which is one panel's height. The grid knows nothing
  # about panels or the chain: {.for_canvas} reads a canvas's size and makes a full grid of it.
  #
  # @example
  #   grid = NhlScoreboard::BoardGrid.new(boards: 7, columns: 4) # 4 on top, 3 below
  #   grid.origin(5)            # => [64, 32]
  #   grid.ticker_band(1).width # => 192
  class BoardGrid
    # @return [Integer] a board's width in columns.
    BOARD_WIDTH = ScoreboardLayout::BOARD_WIDTH

    # @return [Integer] a board's height in rows, above its ticker band.
    BOARD_HEIGHT = ScoreboardLayout::BOARD_HEIGHT

    # @return [Integer] the ticker band's height in rows.
    TICKER_HEIGHT = GoalTicker::DEFAULT_HEIGHT

    # @return [Integer] one row of boards with its ticker band underneath.
    ROW_HEIGHT = BOARD_HEIGHT + TICKER_HEIGHT

    # A row's goal ticker band on the canvas.
    #
    # @!attribute [r] x
    #   @return [Integer] the band's left column, 0.
    # @!attribute [r] top
    #   @return [Integer] the band's first row.
    # @!attribute [r] width
    #   @return [Integer] the band's width in columns: the boards in that row.
    # @!attribute [r] height
    #   @return [Integer] the band's height in rows.
    Band = Struct.new(:x, :top, :width, :height)

    # @return [Integer] how many boards the grid holds.
    attr_reader :boards

    # @return [Integer] boards per row.
    attr_reader :columns

    # @param boards [Integer] how many boards; a positive Integer.
    # @param columns [Integer] boards per row; a positive Integer.
    # @raise [ArgumentError] if either isn't a positive Integer.
    # @example
    #   NhlScoreboard::BoardGrid.new(boards: 2, columns: 2) # two side by side, one row
    def initialize(boards:, columns:)
      raise ArgumentError, "boards must be a positive Integer, got #{boards.inspect}" unless positive_integer?(boards)
      raise ArgumentError, "columns must be a positive Integer, got #{columns.inspect}" unless positive_integer?(columns)

      @boards = boards
      @columns = columns
    end

    # A full grid that fills a canvas: as many 64-column boards across, and 32-row rows down, as fit.
    #
    # @param width [Integer] the canvas width in columns.
    # @param height [Integer] the canvas height in rows.
    # @return [BoardGrid] a grid of +width / 64+ columns and +height / 32+ rows, all full.
    # @raise [ArgumentError] if the canvas holds less than one board across or one row down.
    # @example
    #   NhlScoreboard::BoardGrid.for_canvas(width: 128, height: 32).boards # => 2
    def self.for_canvas(width:, height:)
      columns = width / BOARD_WIDTH
      rows = height / ROW_HEIGHT
      raise ArgumentError, "a #{width}x#{height} canvas holds no boards" if columns.zero? || rows.zero?

      new(boards: columns * rows, columns: columns)
    end

    # @return [Integer] the number of rows of boards, the last one possibly short.
    # @example
    #   NhlScoreboard::BoardGrid.new(boards: 7, columns: 4).rows # => 2
    def rows
      (boards + columns - 1) / columns
    end

    # @return [Integer] the grid's width in columns: the widest row.
    def width
      [boards, columns].min * BOARD_WIDTH
    end

    # @return [Integer] the grid's height in rows, boards and ticker bands together.
    def height
      rows * ROW_HEIGHT
    end

    # @param index [Integer] a board's index, 0 for the first, counting left to right, then down.
    # @return [Array<Integer>] the board's `[x, y]`: its top-left column and row on the canvas.
    # @raise [ArgumentError] if +index+ isn't a board in the grid.
    # @example
    #   NhlScoreboard::BoardGrid.new(boards: 7, columns: 4).origin(4) # => [0, 32]
    def origin(index)
      check_board!(index)
      [(index % columns) * BOARD_WIDTH, (index / columns) * ROW_HEIGHT]
    end

    # @param row [Integer] a row, 0 for the top.
    # @return [Range<Integer>] the indexes of the boards in that row.
    # @raise [ArgumentError] if +row+ isn't a row in the grid.
    # @example
    #   NhlScoreboard::BoardGrid.new(boards: 7, columns: 4).boards_in_row(1) # => 4..6
    def boards_in_row(row)
      check_row!(row)
      first = row * columns
      first..([first + columns, boards].min - 1)
    end

    # @param row [Integer] a row, 0 for the top.
    # @return [Band] the row's ticker band: under its boards, as wide as the boards in it.
    # @raise [ArgumentError] if +row+ isn't a row in the grid.
    # @example
    #   NhlScoreboard::BoardGrid.new(boards: 7, columns: 4).ticker_band(0).width # => 256
    def ticker_band(row)
      Band.new(0, row * ROW_HEIGHT + BOARD_HEIGHT, boards_in_row(row).size * BOARD_WIDTH, TICKER_HEIGHT)
    end

    private

    # @param value [Object] the value to check.
    # @return [Boolean] true for an Integer above zero.
    def positive_integer?(value)
      value.is_a?(Integer) && value.positive?
    end

    # @param index [Integer] the board index.
    # @return [void]
    # @raise [ArgumentError] if the index isn't a board in the grid.
    def check_board!(index)
      raise ArgumentError, "board #{index.inspect} isn't in a grid of #{boards}" unless index.is_a?(Integer) && index.between?(0, boards - 1)
    end

    # @param row [Integer] the row.
    # @return [void]
    # @raise [ArgumentError] if the row isn't a row in the grid.
    def check_row!(row)
      raise ArgumentError, "row #{row.inspect} isn't in a grid of #{rows}" unless row.is_a?(Integer) && row.between?(0, rows - 1)
    end
  end
end
