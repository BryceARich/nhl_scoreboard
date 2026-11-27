# frozen_string_literal: true

module NhlScoreboard
  # Each current NHL team's name as fans say it ("Avalanche", "Golden Knights"), by its tri-code.
  # The goal ticker uses it for the favorite team's goal ("Avalanche GOAL!!!").
  #
  # @example
  #   NhlScoreboard::TeamNames.name_for("COL") # => "Avalanche"
  module TeamNames
    # @return [Hash{String => String}] tri-code to team name, one per current team.
    NAMES = {
      "ANA" => "Ducks", "BOS" => "Bruins", "BUF" => "Sabres", "CAR" => "Hurricanes",
      "CBJ" => "Blue Jackets", "CGY" => "Flames", "CHI" => "Blackhawks", "COL" => "Avalanche",
      "DAL" => "Stars", "DET" => "Red Wings", "EDM" => "Oilers", "FLA" => "Panthers",
      "LAK" => "Kings", "MIN" => "Wild", "MTL" => "Canadiens", "NJD" => "Devils",
      "NSH" => "Predators", "NYI" => "Islanders", "NYR" => "Rangers", "OTT" => "Senators",
      "PHI" => "Flyers", "PIT" => "Penguins", "SEA" => "Kraken", "SJS" => "Sharks",
      "STL" => "Blues", "TBL" => "Lightning", "TOR" => "Maple Leafs", "UTA" => "Mammoth",
      "VAN" => "Canucks", "VGK" => "Golden Knights", "WPG" => "Jets", "WSH" => "Capitals"
    }.freeze

    # The team's name for a code, or the code itself for a code that isn't a current team.
    #
    # @param tri_code [String] the NHL's three-letter team code, such as "COL".
    # @return [String] the team's name, such as "Avalanche".
    # @example
    #   NhlScoreboard::TeamNames.name_for("XYZ") # => "XYZ"
    def self.name_for(tri_code)
      NAMES.fetch(tri_code.to_s.upcase, tri_code.to_s)
    end
  end
end
