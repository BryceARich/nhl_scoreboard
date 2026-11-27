# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

# Fixtures for the layout specs, kept out of the describe block so they are plain constants.
module ScoreboardLayoutSpec
  # Records what the layout asks the canvas to do, so the specs can check positions and text.
  class RecordingCanvas
    attr_reader :texts, :pixels, :fills

    def initialize
      @texts = []
      @pixels = []
      @fills = []
    end

    def fill(r, g, b)
      @fills << [r, g, b]
    end

    def set_pixel(x, y, r, g, b)
      @pixels << [x, y, r, g, b]
    end

    def draw_text(_font, x, y, _r, _g, _b, text)
      @texts << [x, y, text]
    end
  end

  # The fields of SportsIngest::NHL::GameScore that the layout reads.
  Side = Struct.new(:score)
  Game = Struct.new(:phase, :period, :period_type, :clock, :home_team, :away_team)

  # A game in progress or finished, with the given state and the score 3-2 by default.
  def self.game(period: 1, phase: :regulation, period_type: :regulation, clock: "12:34", home: 3, away: 2)
    Game.new(phase, period, period_type, clock, Side.new(home), Side.new(away))
  end
end

RSpec.describe NhlScoreboard::ScoreboardLayout do
  let(:font) { :font }
  let(:layout) { described_class.new(font) }

  # Draws onto a fresh recording canvas and returns it.
  def paint(game, **logos)
    canvas = ScoreboardLayoutSpec::RecordingCanvas.new
    layout.draw(canvas, game, **logos)
    canvas
  end

  # The text the layout drew, as [x, y, text].
  def texts(game)
    paint(game).texts
  end

  it "clears the left 64 columns to black, and leaves the right 64 to the ticker" do
    canvas = paint(ScoreboardLayoutSpec.game)
    expect(canvas.fills).to be_empty
    expect(canvas.pixels).to include([0, 0, 0, 0, 0], [63, 31, 0, 0, 0])
    expect(canvas.pixels.map(&:first).max).to be < 64
  end

  it "puts the period, clock and score at the old layout's positions, using the live state" do
    expect(texts(ScoreboardLayoutSpec.game)).to eq([[24, 6, "1ST"], [19, 13, "12:34"], [24, 20, "3-2"]])
  end

  it "shows the ordinal of each regulation period" do
    expect(texts(ScoreboardLayoutSpec.game(period: 2)).first).to eq([24, 6, "2ND"])
    expect(texts(ScoreboardLayoutSpec.game(period: 3)).first).to eq([24, 6, "3RD"])
  end

  it "shows OT and SO in extra time, and INT between periods" do
    overtime = ScoreboardLayoutSpec.game(period: 4, phase: :overtime, period_type: :overtime)
    shootout = ScoreboardLayoutSpec.game(period: 5, phase: :shootout, period_type: :shootout)
    intermission = ScoreboardLayoutSpec.game(period: 2, phase: :intermission, clock: "00:00")
    expect(texts(overtime).first).to eq([24, 6, "OT"])
    expect(texts(shootout).first).to eq([24, 6, "SO"])
    expect(texts(intermission).first).to eq([24, 6, "INT"])
  end

  it "shows FINAL, with OT or SO in the clock slot after extra time, and blank after regulation" do
    after_overtime = ScoreboardLayoutSpec.game(period: 4, phase: :final, period_type: :overtime, clock: "00:00")
    after_regulation = ScoreboardLayoutSpec.game(period: 3, phase: :final, clock: "00:00")
    expect(texts(after_overtime)).to eq([[24, 6, "FINAL"], [19, 13, "OT"], [24, 20, "3-2"]])
    expect(texts(after_regulation)).to eq([[24, 6, "FINAL"], [19, 13, ""], [24, 20, "3-2"]])
  end

  it "leaves the text blank before the game starts, when the clock and scores are nil" do
    game = ScoreboardLayoutSpec::Game.new(:pre, nil, nil, nil, ScoreboardLayoutSpec::Side.new(nil),
      ScoreboardLayoutSpec::Side.new(nil))
    expect(texts(game)).to eq([[24, 6, ""], [19, 13, ""], [24, 20, ""]])
  end

  it "draws the home logo on the left and the away logo on the right, 20×20 at row 2" do
    home = NhlScoreboard::PpmImage.new(20, 20, "\xFF\x00\x00".b * 400)
    away = NhlScoreboard::PpmImage.new(20, 20, "\x00\x00\xFF".b * 400)
    pixels = paint(ScoreboardLayoutSpec.game, home_logo: home, away_logo: away).pixels
    expect(pixels).to include([0, 2, 255, 0, 0], [19, 21, 255, 0, 0])
    expect(pixels).to include([44, 2, 0, 0, 255], [63, 21, 0, 0, 255])
  end

  it "draws a grey placeholder box in a slot with no logo" do
    pixels = paint(ScoreboardLayoutSpec.game).pixels
    expect(pixels).to include([0, 2, 90, 90, 90], [44, 2, 90, 90, 90], [1, 3, 30, 30, 30])
  end

  it "draws onto a real fake canvas, with the placeholder in the logo slot" do
    fake = NhlScoreboard::FakeCanvas.new(width: 128, height: 32)
    font = NhlScoreboard::BdfFont.load(File.expand_path("../../spec/fixtures/tiny.bdf", __dir__))
    described_class.new(font).draw(fake, ScoreboardLayoutSpec.game)
    expect(fake.pixel(0, 2)).to eq([90, 90, 90])
  end
end
