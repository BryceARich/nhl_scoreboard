# frozen_string_literal: true

require_relative "error"
require_relative "png_encoder"

module NhlScoreboard
  # A canvas kept in memory, with the same methods as {Canvas}, for the Mac. Layout code draws on
  # it the same way it draws on the Pi. Show it with {#to_terminal} (true-colour ANSI blocks) or
  # {#to_png}. It knows nothing about the hardware.
  #
  # Text uses a {BdfFont}, not a {Font}: {Font} needs librgbmatrix, which the Mac doesn't have.
  #
  # @example
  #   canvas = NhlScoreboard::FakeCanvas.new(width: 128, height: 32)
  #   canvas.fill(0, 0, 0)
  #   canvas.set_pixel(10, 4, 255, 0, 0)
  #   puts canvas.to_terminal
  class FakeCanvas
    # @return [Integer] columns.
    attr_reader :width
    # @return [Integer] rows.
    attr_reader :height

    # Makes a black canvas.
    #
    # @param width [Integer] columns, at least 1.
    # @param height [Integer] rows, at least 1.
    # @return [FakeCanvas] the canvas.
    # @raise [Error] if either size is below 1.
    # @example
    #   NhlScoreboard::FakeCanvas.new(width: 128, height: 32)
    def initialize(width:, height:)
      raise Error, "canvas must be at least 1x1, got #{width}x#{height}" if width < 1 || height < 1

      @width = width
      @height = height
      @pixels = Array.new(width * height, 0)
    end

    # Sets one pixel. Like the C library, it silently clips coordinates outside the canvas.
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
      put(x, y, pack(r, g, b))
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
      @pixels.fill(pack(r, g, b))
      nil
    end

    # Clears the canvas to black.
    #
    # @return [nil]
    # @example
    #   canvas.clear
    def clear
      fill(0, 0, 0)
    end

    # Draws UTF-8 text with a BDF font. `x` is the left edge and `y` the baseline, as in
    # {Canvas#draw_text}. Characters the font lacks are skipped and take no space.
    #
    # @param font [BdfFont] the font to draw with.
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
    #   canvas.draw_text(font, 0, 20, 255, 255, 255, "NHL")
    def draw_text(font, x, y, r, g, b, text, kerning_offset: 0)
      check_color!(r, g, b)
      color = pack(r, g, b)
      cursor = x
      text.each_char do |char|
        glyph = font.glyph(char.ord)
        next unless glyph

        draw_glyph(glyph, cursor, y, color)
        cursor += glyph.advance + kerning_offset
      end
      cursor - x
    end

    # The color of one pixel, for checks in specs and for tools.
    #
    # @param x [Integer] column.
    # @param y [Integer] row.
    # @return [Array<Integer>, nil] `[red, green, blue]`, or nil outside the canvas.
    # @example
    #   canvas.pixel(10, 4) # => [255, 0, 0]
    def pixel(x, y)
      value = fetch(x, y)
      return nil unless value

      [(value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff]
    end

    # Draws the canvas as terminal text. Each character cell is a half-block `▀`: its top half is
    # the pixel in row 2n and its bottom half is row 2n+1, so 32 rows make 16 text lines. Needs a
    # terminal with 24-bit colour.
    #
    # @return [String] lines joined by newlines, with ANSI colour codes and a final reset.
    # @example
    #   puts NhlScoreboard::FakeCanvas.new(width: 2, height: 2).to_terminal
    def to_terminal
      (0...height).step(2).map do |y|
        (0...width).map do |x|
          top = fetch(x, y)
          bottom = fetch(x, y + 1) || 0
          "\e[38;2;#{channels(top)}m\e[48;2;#{channels(bottom)}m▀"
        end.join + "\e[0m"
      end.join("\n")
    end

    # Encodes the canvas as a PNG file.
    #
    # @return [String] the PNG bytes, in binary encoding.
    # @example
    #   File.binwrite("preview.png", canvas.to_png)
    def to_png
      rgb = @pixels.flat_map { |value| [(value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff] }
      PngEncoder.encode(width, height, rgb.pack("C*"))
    end

    private

    def draw_glyph(glyph, cursor, baseline, color)
      top = baseline - glyph.y_offset - glyph.height
      glyph.rows.each_with_index do |row, row_index|
        row.each_with_index do |on, column|
          put(cursor + glyph.x_offset + column, top + row_index, color) if on
        end
      end
    end

    def put(x, y, color)
      return unless x.between?(0, width - 1) && y.between?(0, height - 1)

      @pixels[(y * width) + x] = color
    end

    def fetch(x, y)
      return nil unless x.between?(0, width - 1) && y.between?(0, height - 1)

      @pixels[(y * width) + x]
    end

    def channels(value)
      value ||= 0
      [(value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff].join(";")
    end

    def pack(r, g, b)
      (r << 16) | (g << 8) | b
    end

    def check_color!(*channels)
      channels.each do |channel|
        raise Error, "color channel must be 0..255, got #{channel}" unless (0..255).cover?(channel)
      end
    end
  end
end
