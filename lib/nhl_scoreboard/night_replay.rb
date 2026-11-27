# frozen_string_literal: true

require_relative "error"
require_relative "game_recording"

module NhlScoreboard
  # A night of recorded games, played back together on one clock: the games a live loop would see
  # at a given moment. Each game starts when its first snapshot does and holds its last state after
  # its last one, so a finished game stays on the boards as final, the way a live day does.
  #
  # The games come from recordings (see {GameRecording} and {PlayByPlay}), so the snapshots' `at`
  # values are on one clock: seconds since the epoch. The night starts at the earliest game's first
  # snapshot.
  #
  # @example
  #   night = NhlScoreboard::NightReplay.new([snapshots_for_game_a, snapshots_for_game_b])
  #   night.states_at(0)   # => the games that have started, as GameState
  class NightReplay
    # @return [Float] the night's start, in seconds since the epoch: the earliest first snapshot.
    attr_reader :origin

    # @param games [Array<Array<GameRecording::Snapshot>>] one array of snapshots per game. Games with
    #   no snapshots are left out.
    # @raise [Error] if no game has a snapshot.
    # @example
    #   NhlScoreboard::NightReplay.new([GameRecording.read("a.jsonl")])
    def initialize(games)
      @games = games.reject(&:empty?).map { |snapshots| snapshots.sort_by(&:at) }
      raise Error, "a night needs at least one game with a snapshot" if @games.empty?

      @origin = @games.map { |snapshots| snapshots.first.at }.min
    end

    # @return [Integer] how many games the night has.
    def size
      @games.size
    end

    # The games as a live loop would see them, `seconds` into the night: each game that has started,
    # in the order given, in its state at that moment.
    #
    # @param seconds [Numeric] seconds since {#origin}.
    # @return [Array<GameState>] one state for each started game; empty before the first one starts.
    # @example
    #   night.states_at(0).size # => 1 when only one game has started
    def states_at(seconds)
      now = origin + seconds
      @games.filter_map do |snapshots|
        next if snapshots.first.at > now

        index = snapshots.bsearch_index { |snapshot| snapshot.at > now } || snapshots.size
        snapshots[index - 1].state
      end
    end

    # @return [Float] seconds from {#origin} until the last game's last snapshot.
    def duration
      @games.map { |snapshots| snapshots.last.at }.max - origin
    end
  end
end
