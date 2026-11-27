# frozen_string_literal: true

module NhlScoreboard
  # Chooses the games for the two boards (C1-06). The favorite team's game, while it's playing today,
  # always takes board 1, pre-game too. Board 2 takes the other games in turn, each for +dwell+
  # seconds, and prefers live ones: a non-live game only shows when no other game is live. With one
  # game today, board 1 shows it and board 2 stays empty. With no favorite playing, board 1 takes
  # the turn from the same rule, and board 2 takes the next game from the rest.
  #
  # Games are duck-typed: anything that answers +live?+ and +home_team+ and +away_team+ (each with
  # +tri_code+), such as `SportsIngest::NHL::GameScore`. The picker keeps no game data, only the
  # time the rotation started, so a game list that changes between calls still rotates.
  #
  # @example
  #   picker = NhlScoreboard::GamePicker.new(favorite: "COL", dwell: 10)
  #   picker.boards(games, now: Process.clock_gettime(Process::CLOCK_MONOTONIC)) # => [board1, board2]
  class GamePicker
    # @return [Integer] seconds each game holds its board in the rotation.
    DEFAULT_DWELL = 10

    # @return [String, nil] the favorite team's tri-code, upcased, or nil for none.
    attr_reader :favorite

    # @return [Numeric] seconds each game holds its board in the rotation.
    attr_reader :dwell

    # @param favorite [String, nil] the favorite team's tri-code, such as "COL"; nil for none.
    # @param dwell [Numeric] seconds each game holds its board in the rotation; must be positive.
    # @raise [ArgumentError] if +dwell+ isn't positive.
    # @example
    #   NhlScoreboard::GamePicker.new(favorite: "tor").favorite # => "TOR"
    def initialize(favorite: nil, dwell: DEFAULT_DWELL)
      raise ArgumentError, "dwell must be positive, got #{dwell.inspect}" unless dwell.is_a?(Numeric) && dwell.positive?

      @favorite = favorite&.upcase
      @dwell = dwell
      @rotation_started_at = nil
    end

    # The games to show now, board 1 first.
    #
    # @param games [Array<#live?, #home_team, #away_team>] today's games.
    # @param now [Numeric] the current time in seconds, on one clock for every call (such as
    #   +Process.clock_gettime(Process::CLOCK_MONOTONIC)+).
    # @return [Array<Object>] zero to two games: none when +games+ is empty, one when there is only
    #   one game today, else two. Board 1 is the favorite's game if it's playing today.
    # @example
    #   picker.boards([], now: 0) # => []
    def boards(games, now:)
      return [] if games.empty?

      @rotation_started_at ||= now
      slot = ((now - @rotation_started_at) / dwell).floor

      first = favorite_game(games) || rotate(preferred(games), slot)
      rest = games.reject { |game| game.equal?(first) }
      return [first] if rest.empty?

      [first, rotate(preferred(rest), slot)]
    end

    private

    # @param games [Array<#home_team, #away_team>] today's games.
    # @return [Object, nil] the favorite team's game, live or not, or nil when it isn't playing today.
    def favorite_game(games)
      return nil unless favorite

      games.find { |game| game.home_team.tri_code.upcase == favorite || game.away_team.tri_code.upcase == favorite }
    end

    # @param games [Array<#live?>] games to choose from.
    # @return [Array<Object>] the live games, or every game when none is live.
    def preferred(games)
      live = games.select(&:live?)
      live.empty? ? games : live
    end

    # @param games [Array<Object>] a non-empty list.
    # @param slot [Integer] the rotation step.
    # @return [Object] the game at this step, cycling through the list.
    def rotate(games, slot)
      games[slot % games.size]
    end
  end
end
