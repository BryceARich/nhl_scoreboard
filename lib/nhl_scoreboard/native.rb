# frozen_string_literal: true

require "ffi"

require_relative "error"
require_relative "native/matrix_options"
require_relative "native/runtime_options"

module NhlScoreboard
  # FFI binding to the C API of hzeller/rpi-rgb-led-matrix (`include/led-matrix-c.h`, pinned in
  # docs/RESUME.md). Only this module calls C; the rest of the app uses Matrix, Canvas and Font.
  #
  # Loading is lazy so the app and specs load on a Mac without the library. Call {load!} before
  # any C function; it raises {Error} if librgbmatrix isn't installed.
  module Native
    extend FFI::Library

    # The shared library name; FFI looks for librgbmatrix.so on the Pi (`sudo make install`).
    LIBRARY = "rgbmatrix"

    @attached = false

    class << self
      # Loads librgbmatrix and attaches the C functions. Safe to call more than once.
      #
      # @param library [String] shared library name to load; tests pass a missing name.
      # @return [true] once the functions are attached.
      # @raise [Error] if the library can't be found or loaded.
      # @example
      #   NhlScoreboard::Native.load!  # => true on the Pi, raises Error on a Mac
      def load!(library = LIBRARY)
        return true if @attached

        begin
          ffi_lib library
        rescue LoadError => e
          raise Error, "librgbmatrix not found (#{e.message}). Build it on the Pi: docs/RESUME.md, " \
                       "\"Building librgbmatrix (Pi)\"."
        end

        attach_functions
        @attached = true
      end

      private

      def attach_functions
        attach_function :led_matrix_create_from_options_and_rt_options,
          [:pointer, :pointer], :pointer
        attach_function :led_matrix_delete, [:pointer], :void
        attach_function :led_matrix_get_canvas, [:pointer], :pointer
        attach_function :led_matrix_create_offscreen_canvas, [:pointer], :pointer
        attach_function :led_matrix_swap_on_vsync, [:pointer, :pointer], :pointer

        attach_function :led_canvas_get_size, [:pointer, :pointer, :pointer], :void
        attach_function :led_canvas_set_pixel, [:pointer, :int, :int, :uint8, :uint8, :uint8], :void
        attach_function :led_canvas_fill, [:pointer, :uint8, :uint8, :uint8], :void
        attach_function :led_canvas_clear, [:pointer], :void

        attach_function :load_font, [:string], :pointer
        attach_function :delete_font, [:pointer], :void
        attach_function :height_font, [:pointer], :int
        attach_function :baseline_font, [:pointer], :int
        attach_function :draw_text,
          [:pointer, :pointer, :int, :int, :uint8, :uint8, :uint8, :string, :int], :int
      end
    end
  end
end
