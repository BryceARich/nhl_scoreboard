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

    # When a team's game first reaches a period, as seconds into the night. Used to start the night
    # part-way through (`bin/replay_night --from-period`).
    #
    # @param tri_code [String] the team's code, such as "COL"; matched against either side of each game.
    # @param period [Integer] the period, such as 2.
    # @return [Float, nil] seconds from {#origin} to that game's first snapshot in the period or later,
    #   or nil if no game with that team reaches it.
    # @example
    #   night.seconds_into_period("COL", 2) # => 5400.0
    def seconds_into_period(tri_code, period)
      starts = @games.filter_map do |snapshots|
        snapshots.find { |snapshot| team_in?(snapshot.state, tri_code) && snapshot.state.period.to_i >= period }&.at
      end
      starts.min && (starts.min - origin)
    end

    # @return [Float] seconds from {#origin} until the last game's last snapshot.
    def duration
      @games.map { |snapshots| snapshots.last.at }.max - origin
    end

    private

    # @param state [GameState] a game's state.
    # @param tri_code [String] a team's code.
    # @return [Boolean] true when the team plays in the game.
    def team_in?(state, tri_code)
      state.home_team.tri_code == tri_code || state.away_team.tri_code == tri_code
    end
  end
end
