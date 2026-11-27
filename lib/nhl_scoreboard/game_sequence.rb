# frozen_string_literal: true

require_relative "error"
require_relative "game_state"
require_relative "team_logos"

module NhlScoreboard
  # Demos that play a {GameState} out over time. Each returns an Enumerator of states, one per
  # second. Show each with {GameDisplay#show}. The demo is the only thing that changes; the
  # display and the options don't know about it.
  #
  # @example
  #   NhlScoreboard::GameSequence.countdown(state).each { |frame| display.show(frame); sleep 1 }
  module GameSequence
    # Counts the clock down from the state's clock to 00:00, one second per state. The first state
    # is the one given, so the clock shows the starting time first.
    #
    # @param state [GameState] a state with a clock as `MM:SS`.
    # @return [Enumerator<GameState>] the states, from the starting clock down to `00:00`.
    # @raise [Error] if the state has no clock, or the clock isn't `MM:SS`.
    # @example
    #   NhlScoreboard::GameSequence.countdown(state.with(clock: "00:02")).map(&:clock)
    #   # => ["00:02", "00:01", "00:00"]
    def self.countdown(state)
      seconds = seconds_for(state.clock)
      Enumerator.new do |yielder|
        seconds.downto(0) do |left|
          yielder << state.with(clock: format("%02d:%02d", *left.divmod(60)))
        end
      end
    end

    # Puts each current team's logo in the home slot in turn, forever. Scores and the away team
    # stay as they are.
    #
    # @param state [GameState] the state to start from.
    # @return [Enumerator<GameState>] an endless sequence; take as many as you need.
    # @example
    #   NhlScoreboard::GameSequence.cycle_home_logos(state).first(2).map { |s| s.home_team.tri_code }
    def self.cycle_home_logos(state)
      Enumerator.new do |yielder|
        TeamLogos::FILES.keys.cycle do |tri_code|
          home = GameState::Team.new(tri_code: tri_code, score: state.home_team.score)
          yielder << state.with(home_team: home)
        end
      end
    end

    # Plays a recording back, one state a second. Second 0 is the first snapshot's read time. Each
    # second shows the newest snapshot read at or before it, so the frames match what the main loop
    # drew at the time (ADR 0006). A gap between reads holds the last state until the next read.
    #
    # @param snapshots [Array<GameRecording::Snapshot>] the reads, in any order; they're sorted by time.
    # @return [Enumerator<GameState>] one state per second, from the first read to the last. The
    #   first frame is the first read's state.
    # @raise [Error] if there are no snapshots.
    # @example
    #   NhlScoreboard::GameSequence.replay(NhlScoreboard::GameRecording.read("game.jsonl")).first(2)
    def self.replay(snapshots)
      raise Error, "a replay needs at least one snapshot in the recording" if snapshots.empty?

      ordered = snapshots.each_with_index.sort_by { |snapshot, index| [snapshot.at, index] }.map(&:first)
      start = ordered.first.at
      seconds = (ordered.last.at - start).floor
      Enumerator.new do |yielder|
        newest = nil
        reads = ordered.each
        pending = nil
        (0..seconds).each do |second|
          now = start + second
          loop do
            pending ||= reads.next
            break if pending.at > now

            newest = pending.state
            pending = nil
          end
          yielder << newest
        end
      end
    end

    # @api private
    # @param clock [String, nil] a clock as `MM:SS`.
    # @return [Integer] the seconds on it.
    # @raise [Error] if the clock is nil or not `MM:SS`.
    def self.seconds_for(clock)
      raise Error, "a countdown needs a clock in the game state" if clock.nil?
      raise Error, "clock must be MM:SS, got #{clock.inspect}" unless clock.match?(/\A\d+:\d{2}\z/)

      minutes, seconds = clock.split(":").map(&:to_i)
      minutes * 60 + seconds
    end

    private_class_method :seconds_for
  end
end
