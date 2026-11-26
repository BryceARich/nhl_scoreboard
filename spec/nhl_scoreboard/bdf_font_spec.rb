# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::BdfFont do
  let(:path) { File.expand_path("../fixtures/tiny.bdf", __dir__) }

  describe ".load" do
    it "reads the bounding box and the glyphs it encodes" do
      font = described_class.load(path)

      expect(font.height).to eq(4)
      expect(font.baseline).to eq(3)
      expect(font.glyph("I".ord).advance).to eq(3)
      expect(font.glyph("L".ord).y_offset).to eq(-1)
    end

    it "decodes each hex row into booleans, most significant bit first" do
      font = described_class.load(path)

      expect(font.glyph("L".ord).rows.first).to eq([true, false])
      expect(font.glyph("L".ord).rows.last).to eq([true, true])
    end

    it "skips unencoded characters" do
      font = described_class.load(path)

      expect(font.glyph(-1)).to be_nil
      expect(font.glyph("Z".ord)).to be_nil
    end

    it "raises a clear Error for a missing file" do
      expect { described_class.load("/nonexistent/7x13.bdf") }
        .to raise_error(NhlScoreboard::Error, %r{font file not found: /nonexistent/7x13\.bdf})
    end

    it "raises when the file has no bounding box" do
      expect { described_class.parse(["STARTFONT 2.1", "ENDFONT"], "junk.bdf") }
        .to raise_error(NhlScoreboard::Error, /junk\.bdf is not a BDF font/)
    end
  end
end
