# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::LogoLibrary do
  let(:logos) { described_class.load }

  it "loads all 33 team logos, each pre-sized to 20×20" do
    expect(logos.size).to eq(33)
    expect(logos.values.map { |logo| [logo.width, logo.height] }.uniq).to eq([[20, 20]])
  end

  it "names each logo after its file" do
    expect(logos).to include("avalanche", "redwings", "mapleleafs", "kraken", "mammoth")
  end

  it "draws every logo onto the 128×32 canvas" do
    logos.each_value do |logo|
      canvas = NhlScoreboard::FakeCanvas.new(width: 128, height: 32)
      expect { logo.draw(canvas, 54, 6) }.not_to raise_error
      drawn = (6...26).any? { |y| (54...74).any? { |x| canvas.pixel(x, y) != [0, 0, 0] } }
      expect(drawn).to be(true)
    end
  end

  it "raises when the directory is missing" do
    expect { described_class.load("/nope") }.to raise_error(NhlScoreboard::Error, /not found/)
  end
end
