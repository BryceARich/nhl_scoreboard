# frozen_string_literal: true

module NhlScoreboard
  # Chooses the games for the boards (C1-06), for any number of boards: +board_count+ comes from the
  # board grid (see {BoardGrid}). The first board is the favorite team's preference: while the
  # favorite plays today, its game takes the first board, pre-game and final included. The other
  # boards rotate through the remaining games, each game holding its board for +dwell+ seconds, and
  # live games are preferred.
  #
  # The rules, in order:
  # - **Games at or below the board count:** nothing rotates. The favorite comes first, then live
  #   games, then the rest, and the order holds until a game's state changes.
  # - **More games than boards:** the boards show different games, never the same one twice. The
  #   rotation takes the live games when there are enough for the free boards, else live games
  #   first and then the rest.
  #
  # Games are duck-typed: anything that answers +live?+ and +home_team+ and +away_team+ (each with
  # +tri_code+), such as `SportsIngest::NHL::GameScore`. The picker keeps no game data, only the
  # time the rotation started, so a game list that changes between calls still rotates.
  #
  # @example
  #   picker = NhlScoreboard::GamePicker.new(favorite: "COL", dwell: 10, board_count: 2)
  #   picker.boards(games, now: Process.clock_gettime(Process::CLOCK_MONOTONIC)) # => [board1, board2]
  class GamePicker
    # @return [Integer] seconds each game holds its board in the rotation.
    DEFAULT_DWELL = 10

    # @return [Integer] the boards on a 128-column canvas (two 64-column units), the RESUME default.
    DEFAULT_BOARDS = 2

    # @return [String, nil] the favorite team's tri-code, upcased, or nil for none.
    attr_reader :favorite

    # @return [Numeric] seconds each game holds its board in the rotation.
    attr_reader :dwell

    # @return [Integer] how many games the panels show at once.
    attr_reader :board_count

    # @param favorite [String, nil] the favorite team's tri-code, such as "COL"; nil for none.
    # @param dwell [Numeric] seconds each game holds its board in the rotation; must be positive.
    # @param board_count [Integer] how many games the panels show at once; must be a positive Integer.
    # @raise [ArgumentError] if +dwell+ isn't positive, or +board_count+ isn't a positive Integer.
    # @example
    #   NhlScoreboard::GamePicker.new(favorite: "tor", board_count: 3).favorite # => "TOR"
    def initialize(favorite: nil, dwell: DEFAULT_DWELL, board_count: DEFAULT_BOARDS)
      raise ArgumentError, "dwell must be positive, got #{dwell.inspect}" unless dwell.is_a?(Numeric) && dwell.positive?
      raise ArgumentError, "board_count must be a positive Integer, got #{board_count.inspect}" unless board_count.is_a?(Integer) && board_count.positive?

      @favorite = favorite&.upcase
      @dwell = dwell
      @board_count = board_count
      @rotation_started_at = nil
    end

    # The games to show now, first board first.
    #
    # @param games [Array<#live?, #home_team, #away_team>] today's games.
    # @param now [Numeric] the current time in seconds, on one clock for every call (such as
    #   +Process.clock_gettime(Process::CLOCK_MONOTONIC)+).
    # @return [Array<Object>] up to {#board_count} games, all different: none when +games+ is empty,
    #   and every game, in a fixed order, when there are no more games than boards.
    # @example
    #   picker.boards([], now: 0) # => []
    def boards(games, now:)
      return [] if games.empty?
      return ordered(games) if games.size <= board_count

      @rotation_started_at ||= now
      slot = ((now - @rotation_started_at) / dwell).floor
      fav = favorite_game(games)
      free = fav ? board_count - 1 : board_count
      pool = fav ? games.reject { |game| game.equal?(fav) } : games
      shown = free.zero? ? [] : window(pool_for(pool, free), free, slot)
      fav ? [fav, *shown] : shown
    end

    private

    # @param games [Array<#home_team, #away_team>] today's games.
    # @return [Object, nil] the favorite team's game, live or not, or nil when it isn't playing today.
    def favorite_game(games)
      return nil unless favorite

      games.find { |game| game.home_team.tri_code.upcase == favorite || game.away_team.tri_code.upcase == favorite }
    end

    # The fixed order for a day with no more games than boards: favorite, then live, then the rest.
    #
    # @param games [Array<#live?, #home_team, #away_team>] today's games.
    # @return [Array<Object>] every game, in that order, keeping the input order within each group.
    def ordered(games)
      fav = favorite_game(games)
      rest = fav ? games.reject { |game| game.equal?(fav) } : games
      live, other = rest.partition(&:live?)
      (fav ? [fav] : []) + live + other
    end

    # The games the free boards rotate through: the live ones when there are enough for every free
    # board, else all the live ones first and then the rest.
    #
    # @param pool [Array<#live?>] the games that aren't on the favorite's board.
    # @param free [Integer] how many boards rotate.
    # @return [Array<Object>] the rotation pool, live games first.
    def pool_for(pool, free)
      live = pool.select(&:live?)
      return live if live.size >= free

      rest = pool.reject { |game| live.any? { |l| l.equal?(game) } }
      live + rest
    end

    # The games on the free boards at this rotation step. Each step moves the window on by one
    # board's width, so every game gets a turn, and the window never holds the same game twice.
    #
    # @param pool [Array<Object>] the rotation pool, longer than +free+.
    # @param free [Integer] how many boards rotate.
    # @param slot [Integer] the rotation step.
    # @return [Array<Object>] +free+ different games.
    def window(pool, free, slot)
      start = (slot * free) % pool.size
      Array.new(free) { |i| pool[(start + i) % pool.size] }
    end
  end
end
