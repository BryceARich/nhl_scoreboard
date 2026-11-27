# frozen_string_literal: true

require_relative "error"
require_relative "game_recording"
require_relative "game_state"

module NhlScoreboard
  # Turns one game's play-by-play into a recording of reads, one a second of game time, so the
  # replay (GameSequence.replay) shows the game as it went (ADR 0020). The fetch is not here: the
  # payload comes from `/gamecenter/{id}/play-by-play` through `sports_ingest`, and this class only
  # interprets it.
  #
  # Between two plays the clock is interpolated in a straight line, so a stoppage runs down at the
  # same rate as play. A live clock stops at whistles, so a replay drifts from the real clock by the
  # length of each stoppage.
  #
  # Each snapshot's `at` is game time in seconds from the start of the first period, not a read
  # time. Replay only uses the differences between reads, so it plays the same either way.
  #
  # @example
  #   payload = JSON.parse(File.read("game.json"))
  #   NhlScoreboard::PlayByPlay.snapshots(payload).first.state.phase # => :regulation
  class PlayByPlay
    # One play that the timeline uses: when it happened, the state it leaves behind, and the goal it
    # scored (if any).
    #
    # @!attribute [r] elapsed
    #   @return [Integer] seconds from the start of the first period.
    # @!attribute [r] period
    #   @return [Integer] the period number.
    # @!attribute [r] period_type
    #   @return [Symbol] `:regulation`, `:overtime` or `:shootout`.
    # @!attribute [r] remaining
    #   @return [Integer] seconds left in the period when the play happened.
    # @!attribute [r] final
    #   @return [Boolean] whether this play ends the game.
    # @!attribute [r] goal
    #   @return [GameState::Goal, nil] the goal this play scored, if any.
    # @!attribute [r] score
    #   @return [Array(Integer, Integer), nil] the home and away scores after a goal.
    Event = Struct.new(:elapsed, :period, :period_type, :remaining, :final, :goal, :score)

    # The period types the layout knows, keyed by the NHL's code.
    PERIOD_TYPES = {"REG" => :regulation, "OT" => :overtime, "SO" => :shootout}.freeze

    # Reads the timeline of one game.
    #
    # @param payload [Hash] the parsed `/gamecenter/{id}/play-by-play` JSON.
    # @return [Array<GameRecording::Snapshot>] one snapshot a second, from the first play through
    #   the last; empty if the game has no plays.
    # @raise [Error] if the payload isn't shaped as expected.
    # @example
    #   NhlScoreboard::PlayByPlay.snapshots(payload).map(&:at).last
    def self.snapshots(payload)
      new(payload).snapshots
    end

    # @param payload [Hash] the parsed play-by-play JSON, as {.snapshots} takes it.
    # @raise [Error] if the payload isn't shaped as expected.
    def initialize(payload)
      @payload = payload
      @events = build_events
    end

    # @return [Array<GameRecording::Snapshot>] one snapshot a second; see {.snapshots}.
    def snapshots
      return [] if @events.empty?

      last = @events.last.elapsed
      (@events.first.elapsed..last).map do |second|
        index = @events.rindex { |event| event.elapsed <= second } || 0
        GameRecording::Snapshot.new(second.to_f, state_at(second, index))
      end
    end

    private

    def state_at(second, index)
      event = @events[index]
      nxt = @events[index + 1]
      scores = last_score(second)
      GameState.new(
        phase: event.final ? :final : event.period_type,
        period: event.period,
        period_type: event.period_type,
        clock: clock_at(second, event, nxt),
        home_team: GameState::Team.new(tri_code: home_code, score: scores[0]),
        away_team: GameState::Team.new(tri_code: away_code, score: scores[1]),
        goals: goals_by(second)
      )
    end

    def clock_at(second, event, nxt)
      remaining = if nxt && nxt.period == event.period && nxt.elapsed > event.elapsed
        ratio = (second - event.elapsed) / (nxt.elapsed - event.elapsed).to_f
        event.remaining - ((event.remaining - nxt.remaining) * ratio).round
      else
        event.remaining - (second - event.elapsed)
      end
      format("%02d:%02d", *remaining.clamp(0, event.remaining).divmod(60))
    end

    def last_score(second)
      scored = @events.select { |event| event.score && event.elapsed <= second }
      scored.empty? ? [0, 0] : scored.last.score
    end

    def goals_by(second)
      @events.select { |event| event.goal && event.elapsed <= second }.map(&:goal)
    end

    def home_code
      @payload.fetch("homeTeam").fetch("abbrev")
    end

    def away_code
      @payload.fetch("awayTeam").fetch("abbrev")
    end

    # Every play with a period, in game order, with the time it happened as seconds from the start
    # of the game. A period's length is worked out from its own plays (time in period plus time
    # remaining), so overtime and playoff periods need no special case.
    def build_events
      plays = @payload.fetch("plays")
      raise Error, "play-by-play plays must be a list" unless plays.is_a?(Array)

      timed = plays.select { |play| play["periodDescriptor"] }
      lengths = {}
      timed.each do |play|
        number = play.fetch("periodDescriptor").fetch("number")
        total = seconds_for(play.fetch("timeInPeriod")) + seconds_for(play.fetch("timeRemaining"))
        lengths[number] = [lengths[number] || 0, total].max
      end
      offsets = offsets_for(lengths)

      home_code
      away_code
      events = timed.map do |play|
        descriptor = play.fetch("periodDescriptor")
        number = descriptor.fetch("number")
        period_type = PERIOD_TYPES.fetch(descriptor.fetch("periodType")) { :regulation }
        event = Event.new(
          offsets.fetch(number) + seconds_for(play.fetch("timeInPeriod")), number, period_type,
          seconds_for(play.fetch("timeRemaining")), play.fetch("typeDescKey") == "game-end", nil, nil
        )
        goal_for(play, event)
      end
      # Plays come in game order; sorting keeps ties in that order, so the last one at a second wins.
      events.each_with_index.sort_by { |event, index| [event.elapsed, index] }.map(&:first)
    rescue KeyError, TypeError, NoMethodError => e
      raise Error, "play-by-play isn't shaped as expected: #{e.message}"
    end

    # @param play [Hash] one play.
    # @param event [Event] the play as an event.
    # @return [Event] the event, with the goal and the score after it if the play was a goal.
    def goal_for(play, event)
      return event unless play.fetch("typeDescKey") == "goal" && event.period_type != :shootout

      details = play.fetch("details")
      team = details.fetch("eventOwnerTeamId")
      tri_code = (team == @payload.fetch("homeTeam").fetch("id")) ? home_code : away_code
      goal = GameState::Goal.new(
        tri_code: tri_code, period: event.period,
        clock: format("%02d:%02d", *event.remaining.divmod(60)), scorer: scorer_name(details.fetch("scoringPlayerId"))
      )
      event.goal = goal
      event.score = [details.fetch("homeScore"), details.fetch("awayScore")]
      event
    end

    def scorer_name(player_id)
      spot = Array(@payload["rosterSpots"]).find { |candidate| candidate["playerId"] == player_id }
      name = spot && [spot.dig("firstName", "default"), spot.dig("lastName", "default")].compact.join(" ")
      (name.nil? || name.empty?) ? player_id.to_s : name
    end

    # @param lengths [Hash{Integer => Integer}] each period's length in seconds, by number.
    # @return [Hash{Integer => Integer}] the seconds from the start of the game to each period's start.
    def offsets_for(lengths)
      offset = 0
      lengths.keys.sort.to_h do |number|
        start = offset
        offset += lengths.fetch(number)
        [number, start]
      end
    end

    # @param clock [String] a clock as `MM:SS`.
    # @return [Integer] the seconds on it.
    # @raise [Error] if the clock isn't `MM:SS`.
    def seconds_for(clock)
      raise Error, "clock must be MM:SS, got #{clock.inspect}" unless clock.is_a?(String) && clock.match?(/\A\d+:\d{2}\z/)

      minutes, seconds = clock.split(":").map(&:to_i)
      minutes * 60 + seconds
    end
  end
end
