# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::GameDisplay do
  let(:matrix) { NhlScoreboard::FakeMatrix.new(NhlScoreboard::MatrixSettings.new(rows: 32, cols: 64, chain_length: 1)) }
  let(:font) { NhlScoreboard::BdfFont.load(File.expand_path("../fixtures/tiny.bdf", __dir__)) }
  let(:logos) { NhlScoreboard::LogoLibrary.load }
  let(:display) { described_class.new(matrix, NhlScoreboard::ScoreboardLayout.new(font), logos) }

  def state(home:, away:)
    NhlScoreboard::GameState.new(
      phase: :regulation, period: 1, period_type: :regulation, clock: "12:34",
      home_team: NhlScoreboard::GameState::Team.new(tri_code: home, score: 1),
      away_team: NhlScoreboard::GameState::Team.new(tri_code: away, score: 0),
      goals: []
    )
  end

  it "shows the state on the matrix, with each team's logo in its slot" do
    shown = display.show(state(home: "COL", away: "CHI"))
    expect(shown.pixel(0, 2)).to eq(logos.fetch("avalanche").pixel(0, 0))
    expect(shown.pixel(44, 2)).to eq(logos.fetch("blackhawks").pixel(0, 0))
  end

  it "shows a different state with a different logo, from the same display" do
    display.show(state(home: "COL", away: "CHI"))
    shown = display.show(state(home: "VGK", away: "CHI"))
    expect(shown.pixel(0, 2)).to eq(logos.fetch("goldenknights").pixel(0, 0))
  end

  it "draws a placeholder for a team code that has no logo" do
    shown = display.show(state(home: "XYZ", away: "CHI"))
    expect(shown.pixel(0, 2)).to eq([90, 90, 90])
  end
end
