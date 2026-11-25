# frozen_string_literal: true

require_relative "error"
require_relative "native"

module NhlScoreboard
  # A BDF bitmap font for Canvas#draw_text. Load one with {Font.load}; close it when done.
  # The rpi-rgb-led-matrix repo ships BDF files in `fonts/`, such as `7x13.bdf`.
  #
  # @example
  #   font = NhlScoreboard::Font.load("/home/pi/rpi-rgb-led-matrix/fonts/7x13.bdf")
  #   font.height # => 13
  #   font.close
  class Font
    # @return [FFI::Pointer] the C `struct LedFont *`, for Canvas#draw_text.
    attr_reader :pointer

    # Loads a BDF font file.
    #
    # @param path [String] path to the `.bdf` file.
    # @return [Font] the loaded font.
    # @raise [Error] if the file doesn't exist, isn't a BDF font, or librgbmatrix isn't loaded.
    # @example
    #   NhlScoreboard::Font.load("fonts/7x13.bdf")
    def self.load(path)
      raise Error, "font file not found: #{path}" unless File.file?(path)

      Native.load!
      pointer = Native.load_font(path)
      raise Error, "librgbmatrix could not read the BDF font #{path}" if pointer.null?

      new(pointer)
    end

    # Wraps a C font pointer. Use {Font.load}, not this constructor.
    #
    # @param pointer [FFI::Pointer] the C font pointer.
    # @return [Font] the wrapper.
    def initialize(pointer)
      @pointer = pointer
    end

    # Height of the font's glyphs, in pixels.
    #
    # @return [Integer] the height.
    # @raise [Error] if the font is closed.
    # @example
    #   font.height # => 13
    def height
      ensure_open!
      Native.height_font(pointer)
    end

    # Distance from the top of the font to its baseline, in pixels.
    #
    # @return [Integer] the baseline offset.
    # @raise [Error] if the font is closed.
    # @example
    #   font.baseline # => 11
    def baseline
      ensure_open!
      Native.baseline_font(pointer)
    end

    # Frees the font. Calling it again does nothing.
    #
    # @return [nil]
    # @example
    #   font.close
    def close
      return nil if @pointer.nil?

      Native.delete_font(@pointer)
      @pointer = nil
      nil
    end

    private

    def ensure_open!
      raise Error, "font is closed" if @pointer.nil?
    end
  end
end
