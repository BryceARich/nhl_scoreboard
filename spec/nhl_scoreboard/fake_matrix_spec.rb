# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::FakeMatrix do
  subject(:matrix) { described_class.new }

  it "sizes its canvases from the settings: 128 columns by 32 rows by default" do
    expect(matrix.canvas.width).to eq(128)
    expect(matrix.canvas.height).to eq(32)
  end

  it "makes an offscreen canvas of the same size" do
    back = matrix.offscreen_canvas
    expect([back.width, back.height]).to eq([128, 32])
    expect(back).not_to be(matrix.canvas)
  end

  describe "#swap_on_vsync" do
    it "shows the given canvas and returns the previous one as the free buffer" do
      front = matrix.canvas
      back = matrix.offscreen_canvas
      back.fill(255, 0, 0)

      free = matrix.swap_on_vsync(back)

      expect(free).to be(front)
      expect(matrix.canvas).to be(back)
      expect(matrix.canvas.pixel(0, 0)).to eq([255, 0, 0])
    end

    it "refuses a canvas that isn't a FakeCanvas" do
      expect { matrix.swap_on_vsync(Object.new) }.to raise_error(NhlScoreboard::Error, /FakeCanvas/)
    end
  end

  describe "#close" do
    it "refuses later drawing calls, and closing twice is harmless" do
      matrix.close
      matrix.close

      expect { matrix.canvas }.to raise_error(NhlScoreboard::Error, /closed/)
      expect { matrix.offscreen_canvas }.to raise_error(NhlScoreboard::Error, /closed/)
    end
  end
end
