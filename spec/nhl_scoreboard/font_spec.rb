# frozen_string_literal: true

require "tmpdir"
require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::Font do
  describe ".load" do
    it "raises a clear Error for a missing file, before touching librgbmatrix" do
      expect { described_class.load("/nonexistent/7x13.bdf") }
        .to raise_error(NhlScoreboard::Error, %r{font file not found: /nonexistent/7x13\.bdf})
    end
  end

  describe "#close" do
    it "frees the font once, then does nothing" do
      font = described_class.new(FFI::Pointer::NULL)
      allow(NhlScoreboard::Native).to receive(:delete_font)

      font.close
      font.close

      expect(NhlScoreboard::Native).to have_received(:delete_font).once
      expect(font.pointer).to be_nil
    end
  end
end
