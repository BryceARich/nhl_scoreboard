# frozen_string_literal: true

module NhlScoreboard
  # Chooses which game the panels show now (C1-06). A live game with the favorite team always
  # wins. Otherwise the day's games take turns, each for +dwell+ seconds.
  #
  # Games are duck-typed: anything that answers +live?+ and +home_team+ and +away_team+ (each with
  # +tri_code+), such as `SportsIngest::NHL::GameScore`. The picker keeps no game data, only the
  # time the rotation started, so a game list that changes between calls still rotates.
  #
  # @example
  #   picker = NhlScoreboard::GamePicker.new(favorite: "COL", dwell: 10)
  #   picker.pick(games, now: Process.clock_gettime(Process::CLOCK_MONOTONIC))
  class GamePicker
    # @return [Integer] seconds each game holds the panels in the rotation.
    DEFAULT_DWELL = 10

    # @return [String, nil] the favorite team's tri-code, upcased, or nil for none.
    attr_reader :favorite

    # @return [Numeric] seconds each game holds the panels in the rotation.
    attr_reader :dwell

    # @param favorite [String, nil] the favorite team's tri-code, such as "COL"; nil for none.
    # @param dwell [Numeric] seconds each game holds the panels in the rotation; must be positive.
    # @raise [ArgumentError] if +dwell+ isn't positive.
    # @example
    #   NhlScoreboard::GamePicker.new(favorite: "tor").favorite # => "TOR"
    def initialize(favorite: nil, dwell: DEFAULT_DWELL)
      raise ArgumentError, "dwell must be positive, got #{dwell.inspect}" unless dwell.is_a?(Numeric) && dwell.positive?

      @favorite = favorite&.upcase
      @dwell = dwell
      @rotation_started_at = nil
    end

    # The game to show now.
    #
    # @param games [Array<#live?, #home_team, #away_team>] the day's games, in rotation order.
    # @param now [Numeric] the current time in seconds, on one clock for every call (such as
    #   +Process.clock_gettime(Process::CLOCK_MONOTONIC)+).
    # @return [Object, nil] a live favorite game if there is one, else the rotation's game for +now+;
    #   nil when +games+ is empty.
    # @example
    #   picker.pick([], now: 0) # => nil
    def pick(games, now:)
      return nil if games.empty?

      favorite_live = games.find { |game| live_favorite?(game) }
      return favorite_live if favorite_live

      @rotation_started_at ||= now
      games[((now - @rotation_started_at) / dwell).floor % games.size]
    end

    private

    # @param game [#live?, #home_team, #away_team] one game.
    # @return [Boolean] true when the game is live and the favorite team is playing in it.
    def live_favorite?(game)
      return false unless favorite && game.live?

      game.home_team.tri_code.upcase == favorite || game.away_team.tri_code.upcase == favorite
    end
  end
end
