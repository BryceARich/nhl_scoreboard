# frozen_string_literal: true

require_relative "error"
require_relative "native"
require_relative "matrix_settings"
require_relative "canvas"

module NhlScoreboard
  # An open LED matrix on the Pi. Draw on {#canvas} or an {#offscreen_canvas}, then show it with
  # {#swap_on_vsync}. Close it when done so the GPIO is reset.
  #
  # Running this needs root (the library sets up GPIO and a realtime thread) and the panels wired
  # as in docs/RESUME.md. It raises on a Mac, where librgbmatrix isn't installed.
  #
  # @example
  #   NhlScoreboard::Matrix.open do |matrix|
  #     canvas = matrix.offscreen_canvas
  #     canvas.fill(0, 0, 0)
  #     matrix.swap_on_vsync(canvas)
  #   end
  class Matrix
    # @return [MatrixSettings] the settings the matrix was opened with.
    attr_reader :settings

    # Opens the matrix. With a block, it yields the matrix and closes it afterwards.
    #
    # @param settings [MatrixSettings] the panel layout; defaults to the RESUME setup.
    # @yieldparam matrix [Matrix] the open matrix, when a block is given.
    # @return [Matrix, Object] the open matrix, or the block's value when a block is given.
    # @raise [Error] if librgbmatrix isn't installed or the matrix can't be created.
    # @example
    #   matrix = NhlScoreboard::Matrix.open
    #   matrix.close
    def self.open(settings = MatrixSettings.new)
      Native.load!
      options = settings.native_options
      runtime_options = settings.native_runtime_options
      pointer = Native.led_matrix_create_from_options_and_rt_options(options, runtime_options)
      raise Error, "could not create the LED matrix; run as root and check the wiring" if pointer.null?

      matrix = new(pointer, settings)
      return matrix unless block_given?

      begin
        yield matrix
      ensure
        matrix.close
      end
    end

    # Wraps a C matrix pointer. Use {Matrix.open}, not this constructor.
    #
    # @param pointer [FFI::Pointer] the C `struct RGBLedMatrix *`.
    # @param settings [MatrixSettings] the settings the pointer was created with.
    # @return [Matrix] the wrapper.
    def initialize(pointer, settings)
      @pointer = pointer
      @settings = settings
    end

    # The visible canvas. Drawing here shows at once, so prefer {#offscreen_canvas} for animation.
    #
    # @return [Canvas] the active canvas.
    # @raise [Error] if the matrix is closed.
    # @example
    #   matrix.canvas.fill(0, 0, 0)
    def canvas
      ensure_open!
      Canvas.new(Native.led_matrix_get_canvas(@pointer))
    end

    # A second buffer to draw into before showing it with {#swap_on_vsync}.
    #
    # @return [Canvas] a new offscreen canvas owned by this matrix.
    # @raise [Error] if the matrix is closed.
    # @example
    #   canvas = matrix.offscreen_canvas
    def offscreen_canvas
      ensure_open!
      Canvas.new(Native.led_matrix_create_offscreen_canvas(@pointer))
    end

    # Shows a drawn canvas at the next vertical sync, and returns the canvas that was showing.
    # The returned canvas is the free buffer, so draw into it next.
    #
    # @param canvas [Canvas] an offscreen canvas from {#offscreen_canvas}.
    # @return [Canvas] the previously active canvas, now free to draw into.
    # @raise [Error] if the matrix is closed.
    # @example
    #   canvas = matrix.swap_on_vsync(canvas)
    def swap_on_vsync(canvas)
      ensure_open!
      Canvas.new(Native.led_matrix_swap_on_vsync(@pointer, canvas.pointer))
    end

    # Stops the matrix and frees it, which resets the hardware. Calling it again does nothing.
    #
    # @return [nil]
    # @example
    #   matrix.close
    def close
      return nil if @pointer.nil?

      Native.led_matrix_delete(@pointer)
      @pointer = nil
      nil
    end

    private

    def ensure_open!
      raise Error, "matrix is closed" if @pointer.nil?
    end
  end
end
