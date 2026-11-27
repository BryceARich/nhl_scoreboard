# frozen_string_literal: true

require "date"

module NhlScoreboard
  # Today's games for the main loop (ADR 0029). Each read asks the NHL for the games of the local
  # calendar day, the day the app's clock is on, so the loop follows today's games and rolls over at
  # midnight local time. The NHL read itself is passed in, so this class keeps no game data and
  # calls no endpoint: `bin/scoreboard` gives it `SportsIngest::NHL.scores`.
  #
  # @example
  #   source = NhlScoreboard::DayScores.new(scores: ->(date) { SportsIngest::NHL.scores(date: date) })
  #   source.call # => the games for today, as SportsIngest::NHL.scores returns them
  class DayScores
    # @return [#call] reads one day's games; given a Date, returns the games for that day.
    attr_reader :scores

    # @return [#call] returns the current local date.
    attr_reader :today

    # @param scores [#call] given a Date, returns that day's games; raises on failure.
    # @param today [#call] returns the local date as a Date. The default is the app's clock.
    # @example
    #   NhlScoreboard::DayScores.new(scores: ->(date) { [] }, today: -> { Date.new(2026, 11, 27) }).call # => []
    def initialize(scores:, today: -> { Date.today })
      @scores = scores
      @today = today
    end

    # Reads the games for the local day. Errors from +scores+ pass through to the caller, which keeps
    # the last good games (see {MainLoop}).
    #
    # @return [Array<Object>] the day's games, in the order +scores+ returns them.
    # @raise [StandardError] whatever +scores+ raises when the read fails.
    # @example
    #   source.call
    def call
      scores.call(today.call)
    end
  end
end
