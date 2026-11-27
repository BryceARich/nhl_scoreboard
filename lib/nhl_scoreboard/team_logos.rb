# frozen_string_literal: true

module NhlScoreboard
  # Which logo in {LogoLibrary} belongs to each current NHL team, by its tri-code (the NHL's
  # `tri_code`, as on `SportsIngest::NHL::GameTeam`). Look a logo up with
  # `LogoLibrary.load.fetch(TeamLogos.name_for(code))`.
  #
  # Thirty-two teams, one logo each. `mightyducks` and `coyotes` are the old logos and aren't here.
  #
  # @example
  #   NhlScoreboard::TeamLogos.name_for("COL") # => "avalanche"
  module TeamLogos
    # @return [Hash{String => String}] tri-code to logo name, one per current team.
    FILES = {
      "ANA" => "ducks", "BOS" => "bruins", "BUF" => "sabres", "CAR" => "hurricanes",
      "CBJ" => "bluejackets", "CGY" => "flames", "CHI" => "blackhawks", "COL" => "avalanche",
      "DAL" => "stars", "DET" => "redwings", "EDM" => "oilers", "FLA" => "panthers",
      "LAK" => "kings", "MIN" => "wild", "MTL" => "canadiens", "NJD" => "devils",
      "NSH" => "predators", "NYI" => "islanders", "NYR" => "rangers", "OTT" => "senators",
      "PHI" => "flyers", "PIT" => "penguins", "SEA" => "kraken", "SJS" => "sharks",
      "STL" => "blues", "TBL" => "lightning", "TOR" => "mapleleafs", "UTA" => "mammoth",
      "VAN" => "canucks", "VGK" => "goldenknights", "WPG" => "jets", "WSH" => "capitals"
    }.freeze

    # The logo name for a team.
    #
    # @param tri_code [String] the NHL's three-letter team code, such as "COL".
    # @return [String, nil] the logo's name, or nil for a code that isn't a current team.
    # @example
    #   NhlScoreboard::TeamLogos.name_for("XYZ") # => nil
    def self.name_for(tri_code)
      FILES[tri_code]
    end
  end
end
