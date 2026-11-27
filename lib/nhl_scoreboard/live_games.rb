# frozen_string_literal: true

require_relative "game_state"

module NhlScoreboard
  # Turns the day's live games from `sports_ingest` into {GameState}s the display can draw. The
  # scores (`SportsIngest::NHL::GameScore`) have no goals, and the ticker needs them, so each live or
  # final game also gets its goals (read through the gem) with the scorer's name. Goals are read only
  # for games that have started, and each scorer's name is looked up once.
  #
  # The goal and player reads are passed in, so this class calls no endpoint itself. `bin/scoreboard`
  # and `bin/fake_panels --live` pass `SportsIngest::NHL.goals` and `SportsIngest::NHL.player`.
  #
  # @example
  #   live = NhlScoreboard::LiveGames.new(goals: ->(id) { SportsIngest::NHL.goals(id) },
  #     player: ->(id) { SportsIngest::NHL.player(id) })
  #   live.call(SportsIngest::NHL.scores(date: "2026-11-27")) # => [GameState, ...]
  class LiveGames
    # @return [#call] reads a game's goals by its NHL ID, in the gem's goal shape.
    attr_reader :goals

    # @return [#call] reads a player by NHL ID, with +full_name+.
    attr_reader :player

    # @param goals [#call] given a game ID, returns its goals (see +SportsIngest::NHL.goals+).
    # @param player [#call] given a player ID, returns the player with +full_name+ (see +SportsIngest::NHL.player+).
    # @example
    #   NhlScoreboard::LiveGames.new(goals: ->(_id) { [] }, player: ->(_id) { nil })
    def initialize(goals:, player:)
      @goals = goals
      @player = player
      @names = {}
    end

    # The games as states, in the order given. Games that haven't started get no goal read.
    #
    # @param scores [Array<#id, #home_team, #away_team, #phase, #live?, #final?>] the day's games.
    # @return [Array<GameState>] one state per game.
    # @raise [StandardError] whatever the goal or player read raises when it fails.
    # @example
    #   live.call(scores).map(&:phase)
    def call(scores)
      scores.map { |score| state_for(score) }
    end

    private

    # @param score [#id, #home_team, #away_team, #phase, #live?, #final?] one game.
    # @return [GameState] the game as the display draws it, with its goals.
    def state_for(score)
      home = GameState::Team.new(tri_code: score.home_team.tri_code, score: score.home_team.score)
      away = GameState::Team.new(tri_code: score.away_team.tri_code, score: score.away_team.score)
      GameState.new(
        phase: score.phase, period: score.period, period_type: score.period_type, clock: score.clock,
        home_team: home, away_team: away,
        goals: (score.live? || score.final?) ? goals_for(score, home, away) : []
      )
    end

    # @param score [#id] the game.
    # @param home [GameState::Team] the home side, for the goals' team codes.
    # @param away [GameState::Team] the away side.
    # @return [Array<GameState::Goal>] the game's goals, in the NHL's order.
    def goals_for(score, home, away)
      goals.call(score.id).map do |goal|
        team = (goal.side == :home) ? home : away
        GameState::Goal.new(tri_code: team.tri_code, period: goal.period, clock: goal.time_remaining, scorer: scorer_name(goal.scorer_id))
      end
    end

    # @param id [Integer] a player's NHL ID.
    # @return [String] the player's full name, looked up once per ID; the ID as text if the player has no name.
    def scorer_name(id)
      @names[id] ||= begin
        name = player.call(id).full_name.to_s.strip
        name.empty? ? id.to_s : name
      end
    end
  end
end
