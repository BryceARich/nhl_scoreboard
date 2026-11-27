# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

# Fakes shaped like the sports_ingest objects LiveGames reads: a game score, its goals and a player.
module LiveFakes
  Team = Struct.new(:tri_code, :score)
  Score = Struct.new(:id, :home_team, :away_team, :phase, :period, :period_type, :clock) do
    def live? = %i[regulation overtime shootout intermission].include?(phase)

    def final? = phase == :final
  end
  Goal = Struct.new(:side, :period, :time_remaining, :scorer_id)
  Player = Struct.new(:full_name)
end

RSpec.describe NhlScoreboard::LiveGames do
  let(:font) { NhlScoreboard::BdfFont.load(File.expand_path("../fixtures/tiny.bdf", __dir__)) }
  let(:goal_reads) { [] }
  let(:player_reads) { [] }
  let(:goals_by_game) { {} }
  let(:players) { {8478402 => LiveFakes::Player.new("Connor McDavid")} }
  let(:live) do
    described_class.new(
      goals: ->(id) {
        goal_reads << id
        goals_by_game.fetch(id, [])
      },
      player: ->(id) {
        player_reads << id
        players.fetch(id)
      }
    )
  end

  def score(id, phase:, home: "COL", away: "CHI", home_score: 0, away_score: 0)
    LiveFakes::Score.new(id, LiveFakes::Team.new(home, home_score), LiveFakes::Team.new(away, away_score),
      phase, 2, :regulation, "12:34")
  end

  it "turns each score into a state the display draws, with the teams, phase, period and clock" do
    states = live.call([score(1, phase: :regulation, home_score: 2, away_score: 1)])
    state = states.first
    expect(state).to be_a(NhlScoreboard::GameState)
    expect(state.phase).to eq(:regulation)
    expect(state.period).to eq(2)
    expect(state.clock).to eq("12:34")
    expect([state.home_team.tri_code, state.home_team.score]).to eq(["COL", 2])
    expect([state.away_team.tri_code, state.away_team.score]).to eq(["CHI", 1])
  end

  it "reads no goals for a game that hasn't started" do
    states = live.call([score(2, phase: :pre)])
    expect(states.first.goals).to eq([])
    expect(goal_reads).to be_empty
  end

  it "reads the goals of a live or final game, with the scoring team and the scorer's name" do
    goals_by_game[3] = [LiveFakes::Goal.new(:home, 1, "15:01", 8478402), LiveFakes::Goal.new(:away, 2, "04:59", 8478402)]
    goals = live.call([score(3, phase: :final)]).first.goals
    expect(goals.map { |g| [g.tri_code, g.period, g.clock, g.scorer] }).to eq([
      ["COL", 1, "15:01", "Connor McDavid"],
      ["CHI", 2, "04:59", "Connor McDavid"]
    ])
  end

  it "looks each scorer up once" do
    goals_by_game[4] = [LiveFakes::Goal.new(:home, 1, "10:00", 8478402), LiveFakes::Goal.new(:home, 2, "09:00", 8478402)]
    live.call([score(4, phase: :regulation)])
    live.call([score(4, phase: :regulation)])
    expect(player_reads).to eq([8478402])
  end

  it "shows a scorer by the ID when the player has no name" do
    players[9] = LiveFakes::Player.new(nil)
    goals_by_game[5] = [LiveFakes::Goal.new(:away, 1, "01:00", 9)]
    expect(live.call([score(5, phase: :regulation)]).first.goals.first.scorer).to eq("9")
  end

  it "draws a live game with its goals on the display, so the ticker can scroll them" do
    goals_by_game[6] = [LiveFakes::Goal.new(:home, 1, "15:01", 8478402)]
    states = live.call([score(6, phase: :regulation, home_score: 1)])
    matrix = NhlScoreboard::FakeMatrix.new(NhlScoreboard::MatrixSettings.new(rows: 32, cols: 64, chain_length: 1))
    display = NhlScoreboard::GameDisplay.new(matrix, NhlScoreboard::ScoreboardLayout.new(font), NhlScoreboard::LogoLibrary.load,
      ticker: NhlScoreboard::GoalTicker.new(font))
    expect { display.show(states, step: 0) }.not_to raise_error
  end
end
