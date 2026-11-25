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
