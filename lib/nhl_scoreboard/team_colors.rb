# frozen_string_literal: true

module NhlScoreboard
  # The colour each current NHL team's goal text is drawn in on the ticker, by its tri-code (the
  # NHL's `tri_code`). Each is the team's primary colour, as an `[r, g, b]` triple of 0..255.
  #
  # Dark team colours (navy, black) are hard to see on an LED panel, so a few teams use a brighter
  # shade of their colour. The table is a stand-in for the one in `led_scoreboard.py`, which isn't
  # in this repo; check it against that table before the Pi run (see the PR for C1-05).
  #
  # @example
  #   NhlScoreboard::TeamColors.rgb_for("COL") # => [111, 38, 61]
  module TeamColors
    # @return [Hash{String => Array<Integer>}] tri-code to `[r, g, b]`, one per current team.
    RGB = {
      "ANA" => [252, 76, 2], "BOS" => [252, 181, 20], "BUF" => [0, 94, 170],
      "CAR" => [206, 17, 38], "CBJ" => [0, 110, 190], "CGY" => [200, 16, 46],
      "CHI" => [207, 10, 44], "COL" => [140, 60, 90], "DAL" => [0, 104, 71],
      "DET" => [206, 17, 38], "EDM" => [252, 76, 0], "FLA" => [200, 16, 46],
      "LAK" => [162, 170, 173], "MIN" => [40, 150, 100], "MTL" => [175, 30, 45],
      "NJD" => [206, 17, 38], "NSH" => [255, 184, 28], "NYI" => [0, 110, 200],
      "NYR" => [40, 90, 220], "OTT" => [200, 16, 46], "PHI" => [247, 73, 2],
      "PIT" => [252, 181, 20], "SEA" => [99, 217, 217], "SJS" => [0, 150, 160],
      "STL" => [0, 47, 135], "TBL" => [60, 100, 230], "TOR" => [70, 120, 220],
      "UTA" => [105, 211, 220], "VAN" => [0, 110, 210], "VGK" => [185, 151, 91],
      "WPG" => [60, 110, 190], "WSH" => [200, 16, 46]
    }.freeze

    # @return [Array<Integer>] the colour for a code that isn't a current team: white.
    DEFAULT_RGB = [255, 255, 255].freeze

    # The colour a team's text is drawn in.
    #
    # @param tri_code [String] the NHL's three-letter team code, such as "COL".
    # @return [Array<Integer>] `[r, g, b]`; white for a code that isn't a current team.
    # @example
    #   NhlScoreboard::TeamColors.rgb_for("XYZ") # => [255, 255, 255]
    def self.rgb_for(tri_code)
      RGB.fetch(tri_code, DEFAULT_RGB)
    end
  end
end
