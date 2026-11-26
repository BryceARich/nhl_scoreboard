# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::Native do
  describe ".load!" do
    it "raises a clear Error when the library isn't installed" do
      # A name no system has, so this passes on a Mac and on a Pi with librgbmatrix installed.
      expect { described_class.load!("nhl_scoreboard_no_such_rgbmatrix") }
        .to raise_error(NhlScoreboard::Error, /librgbmatrix not found.*Building librgbmatrix/m)
    end
  end
end
