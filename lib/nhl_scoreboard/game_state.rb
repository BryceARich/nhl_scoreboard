# frozen_string_literal: true

require "json"

require_relative "error"

module NhlScoreboard
  # One game's state as the scoreboard shows it: the period, the clock, both teams and their
  # scores, and the goals so far. It has the same readers the layout uses on a
  # `SportsIngest::NHL::GameScore` (ADR 0005), so the live game and a hand-written one draw the
  # same way.
  #
  # Build one from a JSON file with {.load}, or from a Hash with {.from_h}. Change one with {#with}.
  #
  # @example
  #   state = NhlScoreboard::GameState.load("assets/demo_game.json")
  #   state.with(clock: "05:00").clock # => "05:00"
  class GameState < Struct.new(:phase, :period, :period_type, :clock, :home_team, :away_team, :goals)
    # @return [Array<Symbol>] the phases the layout knows, as {GameScore#phase} gives them.
    PHASES = %i[pre regulation overtime shootout intermission final].freeze

    # @return [Array<Symbol>] the period types a period can have.
    PERIOD_TYPES = %i[regulation overtime shootout].freeze

    # One team's side of the score.
    #
    # @!attribute [rw] tri_code
    #   @return [String] the NHL's three-letter code, such as "COL"; {TeamLogos} maps it to a logo.
    # @!attribute [rw] score
    #   @return [Integer, nil] the team's goals, or nil before the game starts.
    Team = Struct.new(:tri_code, :score)

    # One goal, for the goal ticker (C1-05).
    #
    # @!attribute [rw] tri_code
    #   @return [String] the scoring team's code.
    # @!attribute [rw] period
    #   @return [Integer] the period the goal was scored in.
    # @!attribute [rw] clock
    #   @return [String] the time left in the period, as `MM:SS`.
    # @!attribute [rw] scorer
    #   @return [String] who scored, as the ticker will show it.
    Goal = Struct.new(:tri_code, :period, :clock, :scorer)

    # Reads a state from a Hash with string keys, as JSON gives it. Missing sections are an error;
    # missing `goals` is an empty list.
    #
    # @param data [Hash] the state, with keys `phase`, `period`, `period_type`, `clock`,
    #   `home_team`, `away_team`, and optionally `goals`.
    # @return [GameState]
    # @raise [Error] if a key is missing, or a phase or period type isn't one the layout knows.
    # @example
    #   NhlScoreboard::GameState.from_h("phase" => "pre", "home_team" => {"tri_code" => "COL"}, ...)
    def self.from_h(data)
      raise Error, "game state must be an object" unless data.is_a?(Hash)

      new(
        phase: coded(data.fetch("phase"), PHASES, "phase"),
        period: data["period"],
        period_type: data["period_type"] && coded(data["period_type"], PERIOD_TYPES, "period_type"),
        clock: data["clock"],
        home_team: team_from(data.fetch("home_team")),
        away_team: team_from(data.fetch("away_team")),
        goals: (data["goals"] || []).map { |goal| goal_from(goal) }
      )
    rescue KeyError => e
      raise Error, "game state is missing #{e.key.inspect}"
    end

    # Reads a state from a JSON file.
    #
    # @param path [String] the file to read.
    # @return [GameState]
    # @raise [Error] if the file isn't valid JSON, or the state in it is wrong (see {.from_h}).
    # @example
    #   NhlScoreboard::GameState.load("assets/demo_game.json").phase # => :regulation
    def self.load(path)
      from_h(JSON.parse(File.read(path)))
    rescue JSON::ParserError => e
      raise Error, "#{path} is not valid JSON: #{e.message}"
    end

    # A copy of this state with some fields changed. The original is unchanged.
    #
    # @param changes [Hash] the fields to change, by name, such as `clock:`.
    # @return [GameState]
    # @example
    #   state.with(period: 2, clock: "20:00")
    def with(**changes)
      self.class.new(**to_h.merge(changes))
    end

    # The state as a Hash with string keys, in the shape {.from_h} reads. Writing it to JSON and
    # reading it back gives an equal state.
    #
    # @return [Hash{String => Object}] the state, ready for `JSON.generate`.
    # @example
    #   NhlScoreboard::GameState.from_h(state.as_hash) == state # => true
    def as_hash
      {
        "phase" => phase.to_s,
        "period" => period,
        "period_type" => period_type&.to_s,
        "clock" => clock,
        "home_team" => team_hash(home_team),
        "away_team" => team_hash(away_team),
        "goals" => goals.map { |goal| goal_hash(goal) }
      }
    end

    # @api private
    # @param value [String] the JSON value.
    # @param allowed [Array<Symbol>] the symbols it can be.
    # @param field [String] the field's name, for the message.
    # @return [Symbol]
    # @raise [Error] if it isn't one of the allowed symbols.
    def self.coded(value, allowed, field)
      symbol = value.to_s.to_sym
      return symbol if allowed.include?(symbol)

      raise Error, "#{field} must be one of #{allowed.join(", ")}, got #{value.inspect}"
    end

    # @api private
    # @param data [Hash] one team's object.
    # @return [Team]
    def self.team_from(data)
      Team.new(tri_code: data.fetch("tri_code"), score: data["score"])
    end

    # @api private
    # @param data [Hash] one goal's object.
    # @return [Goal]
    def self.goal_from(data)
      Goal.new(tri_code: data.fetch("tri_code"), period: data.fetch("period"),
        clock: data.fetch("clock"), scorer: data.fetch("scorer"))
    end

    # @api private
    # @param team [Team] one team.
    # @return [Hash{String => Object}]
    def team_hash(team)
      {"tri_code" => team.tri_code, "score" => team.score}
    end

    # @api private
    # @param goal [Goal] one goal.
    # @return [Hash{String => Object}]
    def goal_hash(goal)
      {"tri_code" => goal.tri_code, "period" => goal.period, "clock" => goal.clock, "scorer" => goal.scorer}
    end

    private :team_hash, :goal_hash
    private_class_method :coded, :team_from, :goal_from
  end
end
