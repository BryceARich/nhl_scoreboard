# frozen_string_literal: true

module NhlScoreboard
  # Raised when librgbmatrix can't be loaded, a matrix or font can't be created, or a value is out
  # of range before it reaches the C library.
  class Error < StandardError
  end
end
