# frozen_string_literal: true

module NhlScoreboard
  # The games the boards show, held back by a delay (C1-12). Each read of the games is kept with the
  # time it was collected. The boards show the newest read that is at least +delay+ seconds old, so
  # the score, the clock and the goal ticker all move together, from one read.
  #
  # A read is shown at its collection time plus +delay+. Until a read is that old, nothing is shown,
  # so the boards stay blank for the first +delay+ seconds. With a delay of 0 the newest read is
  # shown at once, which is the loop's behaviour without the delay. Reads that never arrive (a failed
  # read) add nothing, so the last good read stays on the boards, as {MainLoop} needs.
  #
  # Reads older than the one on the boards are dropped as the boards move on, so the buffer holds only
  # a few reads at a time.
  #
  # @example
  #   delayed = NhlScoreboard::DelayedGames.new(delay: 30)
  #   delayed.record(0, [game_a])
  #   delayed.at(29)  # => nil, the read is not yet 30 seconds old
  #   delayed.at(30)  # => [game_a]
  class DelayedGames
    # @return [Numeric] seconds each read is held back before it is shown.
    attr_reader :delay

    # @param delay [Numeric] seconds to hold each read back; 0 shows each read at once.
    # @raise [ArgumentError] if +delay+ is negative.
    # @example
    #   NhlScoreboard::DelayedGames.new(delay: 0)
    def initialize(delay: 0)
      raise ArgumentError, "the delay can't be negative, got #{delay}" if delay.negative?

      @delay = delay
      @reads = []
    end

    # Keeps one read of the games, with the time it was collected.
    #
    # @param time [Numeric] the time the read was collected, on the same clock as +now+ in {#at}.
    # @param games [Array<Object>] the games the read returned. The list is copied, so a caller that
    #   changes its array later doesn't change the read.
    # @return [void]
    # @example
    #   delayed.record(12.5, [game])
    def record(time, games)
      @reads << [time, games.dup]
    end

    # The games to show at +now+: the newest read collected at or before +now - delay+. Reads older
    # than that are dropped, since the boards will never show them.
    #
    # @param now [Numeric] the current time, on the same clock as the reads' collection times.
    # @return [Array<Object>, nil] the games of that read, or nil when no read is old enough yet.
    # @example
    #   delayed.at(now) || []
    def at(now)
      index = @reads.rindex { |time, _games| time <= now - delay }
      return nil unless index

      @reads.shift(index) if index.positive?
      @reads.first.last
    end
  end
end
