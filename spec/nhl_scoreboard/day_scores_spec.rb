# frozen_string_literal: true

require "date"
require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::DayScores do
  it "asks for the games of the local day, from the given clock" do
    asked = []
    scores = ->(date) {
      asked << date
      [:game]
    }
    source = described_class.new(scores: scores, today: -> { Date.new(2026, 11, 27) })
    expect(source.call).to eq([:game])
    expect(asked).to eq([Date.new(2026, 11, 27)])
  end

  it "rolls over to the next day's games when the local day does" do
    day = Date.new(2026, 11, 27)
    asked = []
    source = described_class.new(scores: ->(date) {
      asked << date
      []
    }, today: -> { day })
    source.call
    day += 1
    source.call
    expect(asked).to eq([Date.new(2026, 11, 27), Date.new(2026, 11, 28)])
  end

  it "uses the system's local date by default" do
    asked = []
    described_class.new(scores: ->(date) {
      asked << date
      []
    }).call
    expect(asked).to eq([Date.today])
  end

  it "lets a failed read through to the caller" do
    source = described_class.new(scores: ->(_date) { raise IOError, "down" }, today: -> { Date.today })
    expect { source.call }.to raise_error(IOError, "down")
  end
end
