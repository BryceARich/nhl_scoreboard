# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::Canvas do
  # A null pointer stands in for a canvas: every check here fails before any C call.
  subject(:canvas) { described_class.new(FFI::Pointer::NULL) }

  it "rejects a color channel above 255 before calling C" do
    expect { canvas.set_pixel(0, 0, 256, 0, 0) }.to raise_error(NhlScoreboard::Error, /0\.\.255/)
  end

  it "rejects a negative color channel before calling C" do
    expect { canvas.fill(0, -1, 0) }.to raise_error(NhlScoreboard::Error, /0\.\.255/)
  end

  it "rejects a bad color in draw_text before calling C" do
    font = NhlScoreboard::Font.new(FFI::Pointer::NULL)
    expect { canvas.draw_text(font, 0, 0, 0, 0, 999, "hi") }.to raise_error(NhlScoreboard::Error, /999/)
  end
end
