# frozen_string_literal: true

require "ffi"

require_relative "error"
require_relative "native"

module NhlScoreboard
  # A drawing surface owned by a Matrix. The matrix owns the memory, so a Canvas is only valid
  # while its matrix is open. Colors are 0..255 per channel.
  #
  # @example
  #   matrix.canvas.fill(0, 0, 0)
  #   matrix.canvas.set_pixel(0, 0, 255, 255, 255)
  class Canvas
    # @return [FFI::Pointer] the C `struct LedCanvas *`; used by Font drawing and Matrix.
    attr_reader :pointer

    # Wraps a C canvas pointer. Use {Matrix#canvas}, not this constructor.
    #
    # @param pointer [FFI::Pointer] the C canvas pointer from librgbmatrix.
    # @return [Canvas] the wrapper.
    # @example
    #   NhlScoreboard::Canvas.new(matrix_canvas_pointer)
    def initialize(pointer)
      @pointer = pointer
    end

    # Width of the canvas in pixels, as the library reports it.
    #
    # @return [Integer] columns, 128 for the two-panel setup.
    # @example
    #   matrix.canvas.width # => 128
    def width
      size.first
    end

    # Height of the canvas in pixels, as the library reports it.
    #
    # @return [Integer] rows, 32 for the two-panel setup.
    # @example
    #   matrix.canvas.height # => 32
    def height
      size.last
    end

    # Sets one pixel. The library clips coordinates outside the canvas.
    #
    # @param x [Integer] column, 0 at the left.
    # @param y [Integer] row, 0 at the top.
    # @param r [Integer] red, 0..255.
    # @param g [Integer] green, 0..255.
    # @param b [Integer] blue, 0..255.
    # @return [nil]
    # @raise [Error] if a color channel is outside 0..255.
    # @example
    #   canvas.set_pixel(10, 4, 255, 0, 0)
    def set_pixel(x, y, r, g, b)
      check_color!(r, g, b)
      Native.led_canvas_set_pixel(pointer, x, y, r, g, b)
      nil
    end

    # Fills the whole canvas with one color.
    #
    # @param r [Integer] red, 0..255.
    # @param g [Integer] green, 0..255.
    # @param b [Integer] blue, 0..255.
    # @return [nil]
    # @raise [Error] if a color channel is outside 0..255.
    # @example
    #   canvas.fill(0, 0, 0)
    def fill(r, g, b)
      check_color!(r, g, b)
      Native.led_canvas_fill(pointer, r, g, b)
      nil
    end

    # Clears the canvas to black.
    #
    # @return [nil]
    # @example
    #   canvas.clear
    def clear
      Native.led_canvas_clear(pointer)
      nil
    end

    # Draws UTF-8 text with a BDF font. `x` and `y` place the text's baseline origin.
    #
    # @param font [Font] the font to draw with.
    # @param x [Integer] column of the text's left edge.
    # @param y [Integer] baseline row.
    # @param r [Integer] red, 0..255.
    # @param g [Integer] green, 0..255.
    # @param b [Integer] blue, 0..255.
    # @param text [String] the text to draw.
    # @param kerning_offset [Integer] extra space between characters, in pixels.
    # @return [Integer] the width the text advanced, in pixels.
    # @raise [Error] if a color channel is outside 0..255.
    # @example
    #   canvas.draw_text(font, 0, 20, 255, 255, 255, "hello")
    def draw_text(font, x, y, r, g, b, text, kerning_offset: 0)
      check_color!(r, g, b)
      Native.draw_text(pointer, font.pointer, x, y, r, g, b, text, kerning_offset)
    end

    private

    def size
      width_pointer = FFI::MemoryPointer.new(:int)
      height_pointer = FFI::MemoryPointer.new(:int)
      Native.led_canvas_get_size(pointer, width_pointer, height_pointer)
      [width_pointer.read_int, height_pointer.read_int]
    end

    def check_color!(*channels)
      channels.each do |channel|
        raise Error, "color channel must be 0..255, got #{channel}" unless (0..255).cover?(channel)
      end
    end
  end
end
