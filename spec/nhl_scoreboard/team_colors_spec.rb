# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::TeamColors do
  it "has a colour for every team that has a logo" do
    expect(NhlScoreboard::TeamLogos::FILES.keys - described_class::RGB.keys).to be_empty
  end

  it "gives each colour as three channels in 0..255" do
    described_class::RGB.each_value do |rgb|
      expect(rgb.size).to eq(3)
      expect(rgb).to all(be_between(0, 255))
    end
  end

  it "returns the colour for a team's code" do
    expect(described_class.rgb_for("COL")).to eq(described_class::RGB.fetch("COL"))
  end

  it "returns white for a code that isn't a current team" do
    expect(described_class.rgb_for("XYZ")).to eq([255, 255, 255])
  end
end
