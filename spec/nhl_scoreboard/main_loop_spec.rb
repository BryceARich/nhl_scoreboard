# frozen_string_literal: true

require "stringio"
require_relative "../../lib/nhl_scoreboard"

# Fakes for the loop: games in the shape it reads, and a display that records what it shows.
module LoopFakes
  Team = Struct.new(:tri_code, :score)
  Game = Struct.new(:name, :state, :home_team, :away_team) do
    def live? = state == :live
  end

  # Records each game shown, in order, and the scroll step it was shown with.
  class RecordingDisplay
    attr_reader :shown, :steps

    def initialize
      @shown = []
      @steps = []
    end

    def show(game, step: 0)
      @shown << game
      @steps << step
    end
  end

  # The poll waits the loop should ask for, by state, as SportsIngest::NHL::PollInterval gives them.
  POLL = ->(g) { {live: 10, pre: 60, final: nil}.fetch(g.state) }
end

RSpec.describe NhlScoreboard::MainLoop do
  let(:tick_seconds) { NhlScoreboard::MainLoop::SCROLL_SECONDS }

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

  it "draws the chosen game and wakes every scroll tick when nothing needs a sooner read" do
    games.replace([game("pre", state: :pre)])
    loop_ = build
    expect(loop_.tick(0)).to eq(tick_seconds)
    expect(display.shown.map { |boards| boards.map(&:name) }).to eq([["pre"]])
  end

  it "wakes every scroll tick for a live game too" do
    games.replace([game("live", state: :live)])
    expect(build.tick(0)).to eq(tick_seconds)
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
    loop_.tick(10)
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
    loop_.tick(5)
    loop_.tick(65)
    expect(attempts).to eq(3)
  end

  it "shows nothing, and checks again every dwell until the idle read is due" do
    loop_ = build
    expect(loop_.tick(0)).to eq(tick_seconds)
    expect(display.shown).to be_empty
    loop_.tick(300)
    expect(source_calls.size).to eq(2)
  end

  it "scrolls the ticker one column per tick, from the first tick" do
    games.replace([game("live", state: :live)])
    loop_ = build
    loop_.tick(5)
    loop_.tick(5 + tick_seconds)
    loop_.tick(5 + (3 * tick_seconds))
    expect(display.steps).to eq([0, 1, 3])
  end

  it "scrolls on its own clock, so a read or a rotation doesn't reset the ticker" do
    games.replace([game("pre", state: :pre)])
    loop_ = build
    loop_.tick(0)
    loop_.tick(10)
    expect(source_calls.size).to eq(1) # the pre-game read waits 60 s
    expect(display.steps.last).to eq(100)
  end

  it "moves a goal across its band on a real display, once it has scrolled in" do
    font = NhlScoreboard::BdfFont.load(File.expand_path("../fixtures/tiny.bdf", __dir__))
    goal = NhlScoreboard::GameState::Goal.new(tri_code: "CHI", period: 1, clock: "12:34", scorer: "ILL")
    live = NhlScoreboard::GameState.new(
      phase: :regulation, period: 1, period_type: :regulation, clock: "12:34",
      home_team: NhlScoreboard::GameState::Team.new(tri_code: "COL", score: 1),
      away_team: NhlScoreboard::GameState::Team.new(tri_code: "CHI", score: 0),
      goals: [goal]
    )
    matrix = NhlScoreboard::FakeMatrix.new(NhlScoreboard::MatrixSettings.new(rows: 32, cols: 64, chain_length: 1))
    layout = Object.new.tap { |nothing| nothing.define_singleton_method(:draw) { |*, **| nil } }
    real = NhlScoreboard::GameDisplay.new(matrix, layout, {}, ticker: NhlScoreboard::GoalTicker.new(font),
      grid: NhlScoreboard::BoardGrid.new(boards: 1, columns: 1))
    # The goal is scored after the game first shows, so it scrolls; goals there at the first read are history.
    current = live.with(goals: [])
    loop_ = described_class.new(source: -> { [current] }, display: real, picker: NhlScoreboard::GamePicker.new(dwell: 10),
      poll_interval: ->(_game) { 1 }, logger: logger)
    band_lit = -> {
      canvas = matrix.canvas
      (24...32).any? { |y| (0...64).any? { |x| canvas.pixel(x, y).any?(&:positive?) } }
    }

    loop_.tick(0)
    current = live
    loop_.tick(1) # the read sees the goal at step 10; it enters from the right edge at step 0
    expect(band_lit.call).to be(false)
    loop_.tick(3) # step 30: 20 columns in
    expect(band_lit.call).to be(true)
  end

  it "wakes ten times a second through run, with the sleeper" do
    games.replace([game("pre", state: :pre)])
    slept = []
    loop_ = build
    count = 0
    sleeper = ->(seconds) {
      slept << seconds
      throw :done if (count += 1) == 3
    }
    catch(:done) { loop_.run(sleeper: sleeper) }
    expect(slept).to eq([tick_seconds] * 3)
  end
end
