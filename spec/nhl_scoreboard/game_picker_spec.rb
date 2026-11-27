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
    PickerFakes::Game.new(name, state, PickerFakes::Team.new(home, 0), PickerFakes::Team.new(away, 0))
  end

  def names(boards)
    boards.map(&:name)
  end

  let(:fav) { game("fav", home: "COL", away: "CHI") }

  it "shows nothing when there are no games" do
    expect(described_class.new.boards([], now: 0)).to eq([])
  end

  it "shows the only game of the day on board 1 and leaves board 2 empty, favorite or not" do
    expect(names(described_class.new.boards([game("a")], now: 0))).to eq(["a"])
    expect(names(described_class.new(favorite: "COL").boards([fav], now: 0))).to eq(["fav"])
  end

  it "puts the favorite's game on board 1 before puck drop, with another game on board 2" do
    picker = described_class.new(favorite: "COL", dwell: 10)
    expect(names(picker.boards([game("a"), fav], now: 0))).to eq(%w[fav a])
  end

  it "keeps the favorite's game on board 1 while it's live, and later when it's final" do
    picker = described_class.new(favorite: "COL", dwell: 10)
    live_fav = game("fav", state: :live, home: "COL", away: "CHI")
    final_fav = game("fav", state: :final, home: "COL", away: "CHI")
    expect(names(picker.boards([game("a", state: :live), live_fav], now: 0))).to eq(%w[fav a])
    expect(names(picker.boards([game("a", state: :live), final_fav], now: 10))).to eq(%w[fav a])
  end

  it "matches the favorite team on the away side too, and in any case" do
    away_fav = game("fav", home: "CHI", away: "COL")
    picker = described_class.new(favorite: "col", dwell: 10)
    expect(names(picker.boards([game("a"), away_fav], now: 0))).to eq(%w[fav a])
    expect(picker.favorite).to eq("COL")
  end

  it "rotates the other games through board 2, one per dwell" do
    picker = described_class.new(favorite: "COL", dwell: 10)
    games = [fav, game("a"), game("b"), game("c")]
    expect(names(picker.boards(games, now: 0))).to eq(%w[fav a])
    expect(names(picker.boards(games, now: 9.9))).to eq(%w[fav a])
    expect(names(picker.boards(games, now: 10))).to eq(%w[fav b])
    expect(names(picker.boards(games, now: 25))).to eq(%w[fav c])
    expect(names(picker.boards(games, now: 30))).to eq(%w[fav a])
  end

  it "prefers live games on board 2 while any other game is live" do
    picker = described_class.new(favorite: "COL", dwell: 10)
    live = game("live", state: :live)
    games = [fav, game("pre"), live]
    expect(names(picker.boards(games, now: 0))).to eq(%w[fav live])
    expect(names(picker.boards(games, now: 10))).to eq(%w[fav live])
  end

  it "falls back to the rest on board 2 when no other game is live" do
    picker = described_class.new(favorite: "COL", dwell: 10)
    games = [fav, game("p1"), game("p2")]
    expect(names(picker.boards(games, now: 0))).to eq(%w[fav p1])
    expect(names(picker.boards(games, now: 10))).to eq(%w[fav p2])
  end

  it "with no favorite playing, prefers live games on board 1 and takes the next game for board 2" do
    picker = described_class.new(favorite: "COL", dwell: 10)
    games = [game("pre"), game("live", state: :live)]
    expect(names(picker.boards(games, now: 0))).to eq(%w[live pre])
  end

  it "never shows the same game on both boards" do
    picker = described_class.new(favorite: "COL", dwell: 10)
    games = [fav, game("a"), game("b")]
    (0..60).step(5) do |t|
      boards = picker.boards(games, now: t)
      expect(boards.uniq.size).to eq(boards.size)
    end
  end

  it "rejects a dwell that isn't positive" do
    expect { described_class.new(dwell: 0) }.to raise_error(ArgumentError, /dwell/)
    expect { described_class.new(dwell: -1) }.to raise_error(ArgumentError, /dwell/)
  end

  it "holds still with no more games than boards, favorite not playing" do
    picker = described_class.new(dwell: 10)
    games = [game("a", state: :live), game("b", state: :live)]
    shown = (0..60).step(10).map { |t| names(picker.boards(games, now: t)) }
    expect(shown.uniq).to eq([%w[a b]])
  end

  it "rotates three games across two boards, never the same game on both at once" do
    picker = described_class.new(dwell: 10)
    games = [game("a", state: :live), game("b", state: :live), game("c", state: :live)]
    seen = (0..90).step(10).map { |t| names(picker.boards(games, now: t)) }
    seen.each { |pair| expect(pair.uniq.size).to eq(2) }
    expect(seen.flatten.uniq.sort).to eq(%w[a b c])
  end

  it "rotates through all games on the boards, with no two boards on the same game" do
    picker = described_class.new(favorite: "COL", dwell: 10, board_count: 3)
    games = [fav, game("a"), game("b"), game("c"), game("d")]
    (0..80).step(10).each do |t|
      shown = names(picker.boards(games, now: t))
      expect(shown.size).to eq(3)
      expect(shown.uniq.size).to eq(3)
      expect(shown.first).to eq("fav")
    end
    seen = (0..80).step(10).flat_map { |t| names(picker.boards(games, now: t)) }
    expect(seen.uniq.sort).to eq(%w[a b c d fav])
  end

  it "holds still with as many games as boards, favorite first" do
    picker = described_class.new(favorite: "COL", dwell: 10, board_count: 3)
    games = [game("a", state: :live), fav, game("b")]
    shown = (0..60).step(10).map { |t| names(picker.boards(games, now: t)) }
    expect(shown.uniq).to eq([%w[fav a b]])
  end

  it "works with one board: the favorite when it plays, else the rotation" do
    favorite_only = described_class.new(favorite: "COL", dwell: 10, board_count: 1)
    expect(names(favorite_only.boards([game("a"), fav], now: 0))).to eq(%w[fav])
    rotating = described_class.new(dwell: 10, board_count: 1)
    games = [game("a"), game("b")]
    expect(names(rotating.boards(games, now: 0))).to eq(%w[a])
    expect(names(rotating.boards(games, now: 10))).to eq(%w[b])
  end

  it "rejects a board count that isn't a positive Integer" do
    expect { described_class.new(board_count: 0) }.to raise_error(ArgumentError, /board_count/)
    expect { described_class.new(board_count: 2.5) }.to raise_error(ArgumentError, /board_count/)
  end
end
