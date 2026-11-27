# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::DelayedGames do
  it "shows a read at once when there is no delay" do
    delayed = described_class.new
    delayed.record(0, [:a])
    expect(delayed.at(0)).to eq([:a])
  end

  it "shows a read only once it is at least the delay old" do
    delayed = described_class.new(delay: 30)
    delayed.record(100, [:a])
    expect(delayed.at(129.9)).to be_nil
    expect(delayed.at(130)).to eq([:a])
  end

  it "shows nothing before any read is old enough, so the boards stay blank" do
    expect(described_class.new(delay: 30).at(10)).to be_nil
  end

  it "shows the newest read that is old enough, not the newest read" do
    delayed = described_class.new(delay: 30)
    delayed.record(0, [:first])
    delayed.record(10, [:second])
    delayed.record(20, [:third])
    expect(delayed.at(30)).to eq([:first])
    expect(delayed.at(40)).to eq([:second])
    expect(delayed.at(49)).to eq([:second])
    expect(delayed.at(50)).to eq([:third])
  end

  it "keeps the last read on the boards when no newer read arrives, as after a failed read" do
    delayed = described_class.new(delay: 30)
    delayed.record(0, [:only])
    expect(delayed.at(1000)).to eq([:only])
    expect(delayed.at(2000)).to eq([:only])
  end

  it "drops reads the boards have moved past" do
    delayed = described_class.new(delay: 30)
    delayed.record(0, [:first])
    delayed.record(10, [:second])
    delayed.at(40)
    expect(delayed.instance_variable_get(:@reads).map(&:first)).to eq([10])
  end

  it "refuses a negative delay" do
    expect { described_class.new(delay: -1) }.to raise_error(ArgumentError, /can't be negative/)
  end
end
