# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::TeamLogos do
  it "names a logo for each of the 32 current teams, and each names a loaded logo" do
    logos = NhlScoreboard::LogoLibrary.load
    expect(described_class::FILES.size).to eq(32)
    expect(described_class::FILES.values.map { |name| logos.key?(name) }.uniq).to eq([true])
  end

  it "uses one logo per team" do
    expect(described_class::FILES.values.uniq.size).to eq(32)
  end

  it "returns the logo name for a tri-code, and nil for an unknown one" do
    expect(described_class.name_for("COL")).to eq("avalanche")
    expect(described_class.name_for("XYZ")).to be_nil
  end
end
