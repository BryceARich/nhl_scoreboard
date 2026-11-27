# frozen_string_literal: true

require "json"
require "sports_ingest"
require "sports_ingest/nhl"
require_relative "../../lib/nhl_scoreboard"

# Records the text the layout draws, as the scoreboard spec does.
module OverStateSpec
  class RecordingCanvas
    attr_reader :texts

    def initialize
      @texts = []
    end

    def fill(*) = nil

    def set_pixel(*) = nil

    def draw_text(_font, _x, _y, _r, _g, _b, text)
      @texts << text
    end
  end
end

# A finished game whose NHL state code is "OVER" (C1-13). The fixture is synthetic: no real game data.
RSpec.describe "a game in state OVER" do
  let(:payload) { JSON.parse(File.read(File.expand_path("../fixtures/over_game.json", __dir__))) }
  let(:score) { SportsIngest::NHL::GameScore.parse(payload) }
  let(:state) do
    NhlScoreboard::LiveGames.new(goals: ->(_id) { [] }, player: ->(_id) {}).call([score]).first
  end

  it "reads as final in the gem, with its raw code kept" do
    expect(score).to have_attributes(state: :final, phase: :final)
    expect(score.game.codes).to include(state: "OVER")
  end

  it "reaches the display as a final game with its score" do
    expect(state.phase).to eq(:final)
    expect(state.final?).to be(true)
    expect(state.live?).to be(false)
    expect([state.home_team.score, state.away_team.score]).to eq([3, 2])
  end

  it "is drawn as FINAL on the boards" do
    canvas = OverStateSpec::RecordingCanvas.new
    NhlScoreboard::ScoreboardLayout.new(:font).draw(canvas, state)
    expect(canvas.texts).to include("FINAL")
  end
end
