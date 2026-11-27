# frozen_string_literal: true

require "zlib"
require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::FakeCanvas do
  subject(:canvas) { described_class.new(width: 4, height: 2) }

  let(:font) { NhlScoreboard::BdfFont.load(File.expand_path("../fixtures/tiny.bdf", __dir__)) }

  describe "#initialize" do
    it "rejects a canvas smaller than 1x1" do
      expect { described_class.new(width: 0, height: 2) }.to raise_error(NhlScoreboard::Error, /1x1/)
    end
  end

  describe "#set_pixel and #pixel" do
    it "stores a color and reads it back" do
      canvas.set_pixel(1, 1, 255, 128, 3)
      expect(canvas.pixel(1, 1)).to eq([255, 128, 3])
    end

    it "clips coordinates outside the canvas, as the C library does" do
      expect { canvas.set_pixel(-1, 0, 1, 1, 1) }.not_to raise_error
      expect { canvas.set_pixel(4, 0, 1, 1, 1) }.not_to raise_error
      expect(canvas.pixel(4, 0)).to be_nil
    end

    it "rejects a channel outside 0..255" do
      expect { canvas.set_pixel(0, 0, 256, 0, 0) }.to raise_error(NhlScoreboard::Error, /0\.\.255/)
    end
  end

  describe "#fill and #clear" do
    it "fills every pixel, then clears to black" do
      canvas.fill(9, 8, 7)
      expect(canvas.pixel(3, 1)).to eq([9, 8, 7])

      canvas.clear
      expect(canvas.pixel(0, 0)).to eq([0, 0, 0])
    end
  end

  describe "#draw_text" do
    # The tiny font is 4 rows high with its bottom 1 row below the baseline. A glyph's bottom edge
    # sits on the row above the baseline (y), so with y = 4: "I" (y_offset 0) fills rows 0..3 of
    # columns 0..1, and "L" (y_offset -1, one row higher) fills rows 1..3 of column 0 only.
    let(:text_canvas) { described_class.new(width: 8, height: 4) }

    it "draws glyph bitmaps above the baseline and returns the advance" do
      advance = text_canvas.draw_text(font, 0, 4, 255, 255, 255, "IL")

      expect(advance).to eq(6)
      expect(text_canvas.pixel(0, 0)).to eq([255, 255, 255])
      expect(text_canvas.pixel(1, 3)).to eq([255, 255, 255])
      expect(text_canvas.pixel(3, 1)).to eq([255, 255, 255])
      expect(text_canvas.pixel(3, 3)).to eq([255, 255, 255])
      expect(text_canvas.pixel(3, 0)).to eq([0, 0, 0])
      expect(text_canvas.pixel(4, 1)).to eq([0, 0, 0])
    end

    it "skips characters the font lacks and takes no space for them" do
      expect(text_canvas.draw_text(font, 0, 4, 1, 1, 1, "Z")).to eq(0)
      expect(text_canvas.pixel(0, 0)).to eq([0, 0, 0])
    end

    it "adds kerning between characters" do
      expect(text_canvas.draw_text(font, 0, 4, 1, 1, 1, "II", kerning_offset: 1)).to eq(8)
    end

    it "rejects a bad color before drawing" do
      expect { text_canvas.draw_text(font, 0, 4, 0, 0, 999, "I") }.to raise_error(NhlScoreboard::Error, /999/)
    end
  end

  describe "#to_terminal" do
    it "draws one two-space cell per LED, so each row of LEDs is its own line" do
      canvas.set_pixel(0, 0, 255, 0, 0)
      canvas.set_pixel(3, 1, 0, 0, 255)
      lines = canvas.to_terminal.split("\n")

      expect(lines.size).to eq(2)
      expect(lines.first).to start_with("\e[48;2;255;0;0m  \e[48;2;0;0;0m  ")
      expect(lines.last).to end_with("\e[48;2;0;0;255m  \e[0m")
      expect(lines.first).not_to include("▀")
    end

    it "is one line per LED row, with no half blocks" do
      tall = described_class.new(width: 3, height: 5)
      expect(tall.to_terminal.split("\n").size).to eq(5)
      expect(tall.to_terminal).not_to include("▀")
    end
  end

  describe "#to_png" do
    it "writes a PNG whose pixels decode back to the canvas" do
      canvas.fill(0, 0, 0)
      canvas.set_pixel(2, 1, 12, 34, 56)
      png = canvas.to_png

      expect(png.byteslice(0, 8)).to eq("\x89PNG\r\n\x1A\n".b)
      expect(png.byteslice(12, 4)).to eq("IHDR")
      width, height = png.byteslice(16, 8).unpack("NN")
      expect([width, height]).to eq([4, 2])

      idat_at = png.index("IDAT") - 4
      idat_length = png.byteslice(idat_at, 4).unpack1("N")
      raw = Zlib::Inflate.inflate(png.byteslice(idat_at + 8, idat_length))
      # Each row starts with a filter byte of 0; pixel (2, 1) is the 3rd pixel of the 2nd row.
      second_row = raw.byteslice(1 + 4 * 3 + 1, 3 * 4)
      expect(raw.bytesize).to eq(2 * (1 + 4 * 3))
      expect(second_row.byteslice(6, 3).unpack("C3")).to eq([12, 34, 56])
    end

    it "enlarges each LED to a scale-by-scale cell, with a grid line on its last row and column" do
      canvas.fill(0, 0, 0)
      canvas.set_pixel(1, 0, 9, 8, 7)
      png = canvas.to_png(scale: 3)

      width, height = png.byteslice(16, 8).unpack("NN")
      expect([width, height]).to eq([12, 6])

      idat_at = png.index("IDAT") - 4
      raw = Zlib::Inflate.inflate(png.byteslice(idat_at + 8, png.byteslice(idat_at, 4).unpack1("N")))
      # Output row 0 is filter byte + 12 pixels; pixel (1, 0) covers output columns 3..5, and its
      # last column (5) is the grid line.
      first_row = raw.byteslice(1, 12 * 3)
      expect(first_row.byteslice(3 * 3, 3).unpack("C3")).to eq([9, 8, 7])
      expect(first_row.byteslice(4 * 3, 3).unpack("C3")).to eq([9, 8, 7])
      expect(first_row.byteslice(5 * 3, 3).unpack("C3")).to eq([0x28, 0x28, 0x28])
      expect(first_row.byteslice(6 * 3, 3).unpack("C3")).to eq([0, 0, 0])
    end

    it "fills the whole cell when the grid is off" do
      canvas.fill(0, 0, 0)
      canvas.set_pixel(1, 0, 9, 8, 7)
      png = canvas.to_png(scale: 3, grid: false)

      idat_at = png.index("IDAT") - 4
      raw = Zlib::Inflate.inflate(png.byteslice(idat_at + 8, png.byteslice(idat_at, 4).unpack1("N")))
      expect(raw.byteslice(1 + (5 * 3), 3).unpack("C3")).to eq([9, 8, 7])
    end

    it "rejects a scale below 1" do
      expect { canvas.to_png(scale: 0) }.to raise_error(NhlScoreboard::Error, /at least 1/)
    end
  end
end
