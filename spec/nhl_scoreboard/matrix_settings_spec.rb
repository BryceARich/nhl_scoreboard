# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::MatrixSettings do
  describe "defaults" do
    subject(:settings) { described_class.new }

    it "uses the two-panel layout from docs/RESUME.md" do
      expect(settings.rows).to eq(32)
      expect(settings.cols).to eq(32)
      expect(settings.chain_length).to eq(4)
      expect(settings.parallel).to eq(1)
      expect(settings.hardware_mapping).to eq("regular")
      expect(settings.gpio_slowdown).to eq(2)
    end

    it "is 128 columns wide" do
      expect(settings.width).to eq(128)
    end
  end

  describe "#native_options" do
    subject(:options) { described_class.new(rows: 16, chain_length: 2).native_options }

    it "fills the C options struct from the settings" do
      expect(options[:rows]).to eq(16)
      expect(options[:cols]).to eq(32)
      expect(options[:chain_length]).to eq(2)
      expect(options[:parallel]).to eq(1)
    end

    it "points hardware_mapping at the mapping name" do
      expect(options[:hardware_mapping].get_string(0)).to eq("regular")
    end

    it "leaves unset options at zero, so the library uses its defaults" do
      expect(options[:brightness]).to eq(0)
      expect(options[:led_rgb_sequence].null?).to be(true)
    end
  end

  describe "#native_runtime_options" do
    subject(:options) { described_class.new(gpio_slowdown: 3).native_runtime_options }

    it "sets the GPIO slowdown and turns GPIO setup on" do
      expect(options[:gpio_slowdown]).to eq(3)
      expect(options[:do_gpio_init]).to be(true)
    end

    it "keeps daemon mode and privilege dropping off" do
      expect(options[:daemon]).to eq(0)
      expect(options[:drop_privileges]).to eq(0)
    end
  end

  describe "validation" do
    it "rejects a count below 1" do
      expect { described_class.new(rows: 0) }.to raise_error(NhlScoreboard::Error, /rows/)
      expect { described_class.new(chain_length: 0) }.to raise_error(NhlScoreboard::Error, /chain_length/)
    end

    it "rejects a negative GPIO slowdown" do
      expect { described_class.new(gpio_slowdown: -1) }.to raise_error(NhlScoreboard::Error, /gpio_slowdown/)
    end
  end
end
