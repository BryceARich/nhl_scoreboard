# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::PpmImage do
  # A 2×1 image: red, then green. The comment line is legal in a P6 header.
  let(:two_pixels) { "P6\n# made by hand\n2 1\n255\n\xFF\x00\x00\x00\xFF\x00".b }

  describe ".parse" do
    it "reads the size and pixels" do
      image = described_class.parse(two_pixels)
      expect([image.width, image.height]).to eq([2, 1])
      expect(image.pixel(0, 0)).to eq([255, 0, 0])
      expect(image.pixel(1, 0)).to eq([0, 255, 0])
    end

    it "returns nil outside the image" do
      image = described_class.parse(two_pixels)
      expect(image.pixel(2, 0)).to be_nil
      expect(image.pixel(0, 1)).to be_nil
    end

    it "rejects a file that isn't P6" do
      expect { described_class.parse("P3\n1 1\n255\n0 0 0\n") }.to raise_error(NhlScoreboard::Error, /P6/)
    end

    it "rejects a maxval other than 255" do
      expect { described_class.parse("P6\n1 1\n15\n\x00\x00\x00".b) }.to raise_error(NhlScoreboard::Error, /255/)
    end

    it "rejects truncated pixel data" do
      expect { described_class.parse("P6\n2 1\n255\n\x00\x00\x00".b) }.to raise_error(NhlScoreboard::Error, /truncated/)
    end
  end

  describe ".load" do
    it "raises when the file doesn't exist" do
      expect { described_class.load("/nope/logo.ppm") }.to raise_error(NhlScoreboard::Error, /not found/)
    end
  end

  describe "#to_ppm" do
    it "round-trips through .parse" do
      image = described_class.parse(two_pixels)
      again = described_class.parse(image.to_ppm)
      expect(again.pixel(1, 0)).to eq([0, 255, 0])
    end
  end

  describe "#resize_box" do
    it "averages each box of source pixels" do
      # 2×2: black, white / white, black, so the one output pixel is mid grey
      data = [0, 0, 0, 255, 255, 255, 255, 255, 255, 0, 0, 0].pack("C*")
      image = described_class.new(2, 2, data)
      expect(image.resize_box(1, 1).pixel(0, 0)).to eq([128, 128, 128])
    end

    it "makes a 20×20 copy of a 128×128 image" do
      image = described_class.new(128, 128, "\x40\x80\xC0".b * (128 * 128))
      small = image.resize_box(20, 20)
      expect([small.width, small.height]).to eq([20, 20])
      expect(small.pixel(19, 19)).to eq([0x40, 0x80, 0xC0])
    end
  end

  describe "#draw" do
    it "leaves transparent pixels alone" do
      canvas = NhlScoreboard::FakeCanvas.new(width: 4, height: 2)
      canvas.set_pixel(1, 1, 9, 9, 9)
      keyed = "P6\n2 1\n255\n\xFF\x00\xFF\x00\xFF\x00".b
      described_class.parse(keyed).draw(canvas, 1, 1)
      expect(canvas.pixel(1, 1)).to eq([9, 9, 9])
      expect(canvas.pixel(2, 1)).to eq([0, 255, 0])
    end

    it "puts every pixel on the canvas at the offset" do
      canvas = NhlScoreboard::FakeCanvas.new(width: 4, height: 2)
      described_class.parse(two_pixels).draw(canvas, 1, 1)
      expect(canvas.pixel(1, 1)).to eq([255, 0, 0])
      expect(canvas.pixel(2, 1)).to eq([0, 255, 0])
      expect(canvas.pixel(0, 0)).to eq([0, 0, 0])
    end
  end
end
