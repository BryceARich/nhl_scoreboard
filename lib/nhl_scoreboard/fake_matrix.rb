# frozen_string_literal: true

require_relative "error"
require_relative "matrix_settings"
require_relative "fake_canvas"

module NhlScoreboard
  # An in-memory stand-in for {Matrix} on the Mac, with the same `canvas`, `offscreen_canvas`,
  # `swap_on_vsync` and `close`. Its canvases are {FakeCanvas}es, sized from the settings. Nothing
  # is shown on a panel. Read the frame with {FakeCanvas#to_terminal} or {FakeCanvas#to_png}, or
  # show it in a browser with {PreviewServer}.
  #
  # @example
  #   matrix = NhlScoreboard::FakeMatrix.new
  #   back = matrix.offscreen_canvas
  #   back.fill(255, 0, 0)
  #   matrix.swap_on_vsync(back)
  #   puts matrix.canvas.to_terminal
  class FakeMatrix
    # @return [MatrixSettings] the settings the fake was built with.
    attr_reader :settings

    # Builds the fake with a black visible canvas.
    #
    # @param settings [MatrixSettings] the panel layout; defaults to the RESUME setup, 128×32.
    # @return [FakeMatrix] the fake matrix.
    # @example
    #   NhlScoreboard::FakeMatrix.new.canvas.width # => 128
    def initialize(settings = MatrixSettings.new)
      @settings = settings
      @closed = false
      @active = new_canvas
    end

    # The visible canvas. Drawing here shows at once, as on the real matrix.
    #
    # @return [FakeCanvas] the active canvas.
    # @raise [Error] if the matrix is closed.
    # @example
    #   matrix.canvas.fill(0, 0, 0)
    def canvas
      ensure_open!
      @active
    end

    # A second buffer to draw into before showing it with {#swap_on_vsync}.
    #
    # @return [FakeCanvas] a new black canvas of the matrix's size.
    # @raise [Error] if the matrix is closed.
    # @example
    #   canvas = matrix.offscreen_canvas
    def offscreen_canvas
      ensure_open!
      new_canvas
    end

    # Makes `canvas` the visible one and returns the previous visible canvas, which is free to draw
    # into next. There is no vsync to wait for, so the swap is immediate.
    #
    # @param canvas [FakeCanvas] a canvas from {#offscreen_canvas}.
    # @return [FakeCanvas] the previously visible canvas.
    # @raise [Error] if the matrix is closed or `canvas` is not a {FakeCanvas}.
    # @example
    #   canvas = matrix.swap_on_vsync(canvas)
    def swap_on_vsync(canvas)
      ensure_open!
      raise Error, "swap_on_vsync needs a FakeCanvas, got #{canvas.class}" unless canvas.is_a?(FakeCanvas)

      previous = @active
      @active = canvas
      previous
    end

    # Marks the fake closed, like {Matrix#close}. Calling it again does nothing.
    #
    # @return [nil]
    # @example
    #   matrix.close
    def close
      @closed = true
      nil
    end

    private

    def new_canvas
      FakeCanvas.new(width: settings.width, height: settings.rows)
    end

    def ensure_open!
      raise Error, "matrix is closed" if @closed
    end
  end
end
