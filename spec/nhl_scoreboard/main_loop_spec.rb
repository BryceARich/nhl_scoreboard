# frozen_string_literal: true

require "stringio"
require_relative "../../lib/nhl_scoreboard"

# Fakes for the loop: games in the shape it reads, and a display that records what it shows.
module LoopFakes
  Team = Struct.new(:tri_code, :score)
  Game = Struct.new(:name, :state, :home_team, :away_team) do
    def live? = state == :live
  end

  # Records each game shown, in order.
  class RecordingDisplay
    attr_reader :shown

    def initialize
      @shown = []
    end

    def show(game)
      @shown << game
    end
  end

  # The poll waits the loop should ask for, by state, as SportsIngest::NHL::PollInterval gives them.
  POLL = ->(g) { {live: 10, pre: 60, final: nil}.fetch(g.state) }
end

RSpec.describe NhlScoreboard::MainLoop do
  def game(name, state: :pre)
    LoopFakes::Game.new(name: name, state: state, home_team: LoopFakes::Team.new("AAA", 0), away_team: LoopFakes::Team.new("BBB", 0))
  end

  let(:display) { LoopFakes::RecordingDisplay.new }
  let(:picker) { NhlScoreboard::GamePicker.new(dwell: 10) }
  let(:logger) { StringIO.new }
  let(:games) { [] }
  let(:source_calls) { [] }
  let(:source) {
    -> {
      source_calls << true
      games.is_a?(Proc) ? games.call : games
    }
  }

  def build(source: self.source)
    described_class.new(source: source, display: display, picker: picker, poll_interval: LoopFakes::POLL, logger: logger)
  end

  it "draws the chosen game and sleeps for the rotation when nothing needs a sooner read" do
    games.replace([game("pre", state: :pre)])
    loop_ = build
    expect(loop_.tick(0)).to eq(10)
    expect(display.shown.map { |boards| boards.map(&:name) }).to eq([["pre"]])
  end

  it "sleeps for a live game's poll interval when it's shorter than the rotation" do
    games.replace([game("live", state: :live)])
    expect(build.tick(0)).to eq(10)
  end

  it "reads again only once the poll interval is up" do
    games.replace([game("pre", state: :pre)])
    loop_ = build
    loop_.tick(0)
    loop_.tick(9)
    expect(source_calls.size).to eq(1)
    loop_.tick(60)
    expect(source_calls.size).to eq(2)
  end

  it "rereads every idle period when every game is final" do
    games.replace([game("done", state: :final)])
    loop_ = build
    loop_.tick(0)
    300.step(by: 10, to: 290) { |t| loop_.tick(t) }
    expect(source_calls.size).to eq(1)
    loop_.tick(300)
    expect(source_calls.size).to eq(2)
  end

  it "keeps the last games on the panels when a read fails, and backs off" do
    failing = false
    flaky = -> do
      source_calls << true
      raise SocketError, "no route to host" if failing
      [game("live", state: :live)]
    end
    loop_ = build(source: flaky)
    loop_.tick(0)
    failing = true
    expect(loop_.tick(10)).to eq(5) # the game stays up; the retry is due in 5s
    expect(display.shown.map { |boards| boards.map(&:name) }).to eq([["live"], ["live"]])
    expect(logger.string).to include("read failed (SocketError: no route to host)")
  end

  it "retries after 5, 10, 20 seconds while the source stays down, capped at 300" do
    failing = -> {
      source_calls << true
      raise IOError, "down"
    }
    loop_ = build(source: failing)
    loop_.tick(0)
    expect(source_calls.size).to eq(1)
    loop_.tick(4)
    expect(source_calls.size).to eq(1)
    loop_.tick(5)
    expect(source_calls.size).to eq(2)
    loop_.tick(14)
    expect(source_calls.size).to eq(2)
    loop_.tick(15)
    expect(source_calls.size).to eq(3)
    loop_.tick(35)
    expect(source_calls.size).to eq(4)
    (1..10).each { |i| loop_.tick(1000 * i) }
    expect(logger.string.lines.last).to include("retry in 300s")
  end

  it "goes back to normal polling as soon as a read works again" do
    attempts = 0
    recovering = -> do
      attempts += 1
      raise IOError, "down" if attempts == 1
      [game("pre", state: :pre)]
    end
    loop_ = build(source: recovering)
    loop_.tick(0)
    loop_.tick(5)
    expect(loop_.tick(5)).to eq(10)
    loop_.tick(65)
    expect(attempts).to eq(3)
  end

  it "shows nothing, and checks again every dwell until the idle read is due" do
    loop_ = build
    expect(loop_.tick(0)).to eq(10)
    expect(display.shown).to be_empty
    loop_.tick(300)
    expect(source_calls.size).to eq(2)
  end

  it "never sleeps for less than a second" do
    games.replace([game("live", state: :live)])
    picker_zero = NhlScoreboard::GamePicker.new(dwell: 0.2)
    loop_ = described_class.new(source: source, display: display, picker: picker_zero, poll_interval: LoopFakes::POLL, logger: logger)
    expect(loop_.tick(0)).to eq(1)
  end

  it "sleeps through run with the sleeper, one tick at a time" do
    games.replace([game("pre", state: :pre)])
    slept = []
    loop_ = build
    count = 0
    sleeper = ->(seconds) {
      slept << seconds
      throw :done if (count += 1) == 3
    }
    catch(:done) { loop_.run(sleeper: sleeper) }
    expect(slept).to eq([10, 10, 10])
  end
end
