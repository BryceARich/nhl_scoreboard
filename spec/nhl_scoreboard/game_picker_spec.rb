# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

# Fake games in the shape the picker reads: +live?+, +home_team+ and +away_team+ with +tri_code+.
module PickerFakes
  Team = Struct.new(:tri_code, :score)
  Game = Struct.new(:name, :state, :home_team, :away_team) do
    def live? = state == :live
  end
end

RSpec.describe NhlScoreboard::GamePicker do
  def game(name, state: :pre, home: "AAA", away: "BBB")
    PickerFakes::Game.new(name: name, state: state, home_team: PickerFakes::Team.new(home, 0), away_team: PickerFakes::Team.new(away, 0))
  end

  let(:a) { game("a") }
  let(:b) { game("b") }
  let(:c) { game("c") }

  it "picks nothing when there are no games" do
    expect(described_class.new.pick([], now: 0)).to be_nil
  end

  it "takes turns through the games, each for the dwell time" do
    picker = described_class.new(dwell: 10)
    games = [a, b, c]
    expect(picker.pick(games, now: 0).name).to eq("a")
    expect(picker.pick(games, now: 9.9).name).to eq("a")
    expect(picker.pick(games, now: 10).name).to eq("b")
    expect(picker.pick(games, now: 25).name).to eq("c")
    expect(picker.pick(games, now: 30).name).to eq("a")
  end

  it "keeps the rotation going when the game list changes size" do
    picker = described_class.new(dwell: 10)
    picker.pick([a, b, c], now: 0)
    expect(picker.pick([a, b], now: 10).name).to eq("b")
  end

  it "shows a live game with the favorite team, ahead of the rotation" do
    favorite = game("fav", state: :live, home: "COL", away: "CHI")
    picker = described_class.new(favorite: "COL", dwell: 10)
    expect(picker.pick([a, favorite, b], now: 0)).to be(favorite)
    expect(picker.pick([a, favorite, b], now: 10)).to be(favorite)
  end

  it "matches the favorite team on the away side too, and in any case" do
    favorite = game("fav", state: :live, home: "CHI", away: "COL")
    picker = described_class.new(favorite: "col", dwell: 10)
    expect(picker.pick([a, favorite], now: 0)).to be(favorite)
    expect(picker.favorite).to eq("COL")
  end

  it "doesn't show the favorite team's game before it's live" do
    upcoming = game("fav", state: :pre, home: "COL", away: "CHI")
    picker = described_class.new(favorite: "COL", dwell: 10)
    expect(picker.pick([a, upcoming], now: 0)).to be(a)
  end

  it "doesn't show a live game without the favorite team ahead of the rotation" do
    live = game("other", state: :live)
    picker = described_class.new(favorite: "COL", dwell: 10)
    expect(picker.pick([live], now: 0)).to be(live)
    expect(picker.pick([a, live], now: 0)).to be(a)
  end

  it "rejects a dwell that isn't positive" do
    expect { described_class.new(dwell: 0) }.to raise_error(ArgumentError, /dwell/)
    expect { described_class.new(dwell: -1) }.to raise_error(ArgumentError, /dwell/)
  end
end
