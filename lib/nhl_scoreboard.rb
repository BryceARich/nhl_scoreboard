# frozen_string_literal: true

# Entry point for the scoreboard's library code. Requiring it loads no native code: librgbmatrix is
# only loaded when a Matrix is opened (see NhlScoreboard::Native.load!).
module NhlScoreboard
end

require_relative "nhl_scoreboard/error"
require_relative "nhl_scoreboard/native"
require_relative "nhl_scoreboard/matrix_settings"
require_relative "nhl_scoreboard/canvas"
require_relative "nhl_scoreboard/font"
require_relative "nhl_scoreboard/matrix"
require_relative "nhl_scoreboard/bdf_font"
require_relative "nhl_scoreboard/png_encoder"
require_relative "nhl_scoreboard/ppm_image"
require_relative "nhl_scoreboard/logo_library"
require_relative "nhl_scoreboard/team_logos"
require_relative "nhl_scoreboard/scoreboard_layout"
require_relative "nhl_scoreboard/game_state"
require_relative "nhl_scoreboard/game_sequence"
require_relative "nhl_scoreboard/game_display"
require_relative "nhl_scoreboard/fake_canvas"
require_relative "nhl_scoreboard/fake_matrix"
require_relative "nhl_scoreboard/preview_server"
