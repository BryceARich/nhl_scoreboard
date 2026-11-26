# frozen_string_literal: true

require_relative "error"

module NhlScoreboard
  # A pure-Ruby reader for BDF bitmap fonts, used by {FakeCanvas}. It needs no librgbmatrix, so the
  # Mac draws the same text the Pi does. It reads the glyphs the file has and skips the rest.
  #
  # @example
  #   font = NhlScoreboard::BdfFont.load("fonts/7x13.bdf")
  #   font.height # => 13
  #   font.glyph(0x41).advance # => 7
  class BdfFont
    # One character's bitmap. `rows` runs top to bottom; each row is an array of booleans, left to
    # right, `width` long. `x_offset` and `y_offset` place the bitmap from the origin and baseline.
    Glyph = Struct.new(:width, :height, :x_offset, :y_offset, :advance, :rows)

    # @return [Integer] the font's bounding-box height in pixels, as the C font reports it.
    attr_reader :height
    # @return [Integer] the distance from the top of the font to its baseline, in pixels.
    attr_reader :baseline

    # Reads a BDF file.
    #
    # @param path [String] path to the `.bdf` file.
    # @return [BdfFont] the parsed font.
    # @raise [Error] if the file doesn't exist or has no FONTBOUNDINGBOX line.
    # @example
    #   NhlScoreboard::BdfFont.load("fonts/7x13.bdf")
    def self.load(path)
      raise Error, "font file not found: #{path}" unless File.file?(path)

      parse(File.foreach(path, chomp: true), path)
    end

    # Parses BDF lines. Used by {.load}; exposed so specs can parse a string.
    #
    # @param lines [Enumerable<String>] the file's lines, without newlines.
    # @param source [String] a name for error messages.
    # @return [BdfFont] the parsed font.
    # @raise [Error] if there is no FONTBOUNDINGBOX line.
    # @example
    #   NhlScoreboard::BdfFont.parse(File.readlines("fonts/7x13.bdf", chomp: true), "7x13.bdf")
    def self.parse(lines, source = "BDF")
      font = {height: nil, baseline: nil, glyphs: {}}
      glyph = nil
      in_bitmap = false
      lines.each do |line|
        if in_bitmap
          if line == "ENDCHAR"
            store_glyph(font, glyph) if glyph
            glyph = nil
            in_bitmap = false
          else
            glyph[:rows] << line.strip
          end
          next
        end

        keyword, *args = line.split
        case keyword
        when "FONTBOUNDINGBOX"
          _width, height, _x, y_offset = args.map(&:to_i)
          font[:height] = height
          font[:baseline] = height + y_offset
        when "STARTCHAR"
          glyph = {code: -1, advance: nil, bbx: nil, rows: []}
        when "ENCODING"
          glyph[:code] = args.first.to_i if glyph
        when "DWIDTH"
          glyph[:advance] = args.first.to_i if glyph
        when "BBX"
          glyph[:bbx] = args.map(&:to_i) if glyph
        when "BITMAP"
          in_bitmap = true if glyph
        end
      end
      raise Error, "#{source} is not a BDF font: no FONTBOUNDINGBOX" unless font[:height]

      new(font[:height], font[:baseline], font[:glyphs])
    end

    # Builds a font from parsed parts. Use {.load} or {.parse}.
    #
    # @param height [Integer] bounding-box height.
    # @param baseline [Integer] baseline offset from the top.
    # @param glyphs [Hash{Integer => Glyph}] glyphs keyed by Unicode codepoint.
    # @return [BdfFont] the font.
    def initialize(height, baseline, glyphs)
      @height = height
      @baseline = baseline
      @glyphs = glyphs
    end

    # The glyph for one codepoint.
    #
    # @param codepoint [Integer] for example `"A".ord`.
    # @return [Glyph, nil] the glyph, or nil if the font doesn't have it.
    # @example
    #   font.glyph("A".ord).width # => 5
    def glyph(codepoint)
      @glyphs[codepoint]
    end

    # Stores a finished glyph hash as a {Glyph}, skipping unencoded characters.
    #
    # @api private
    def self.store_glyph(font, glyph)
      return if glyph[:code].negative? || glyph[:bbx].nil?

      width, height, x_offset, y_offset = glyph[:bbx]
      advance = glyph[:advance] || width
      rows = glyph[:rows].map { |hex| decode_row(hex, width) }
      font[:glyphs][glyph[:code]] = Glyph.new(width, height, x_offset, y_offset, advance, rows)
    end

    # Turns one hex row into booleans, most significant bit first.
    #
    # @api private
    def self.decode_row(hex, width)
      value = hex.to_i(16)
      bits = hex.length * 4
      Array.new(width) { |column| value[bits - 1 - column] == 1 }
    end
    private_class_method :store_glyph, :decode_row
  end
end
