# frozen_string_literal: true

require "zlib"

module NhlScoreboard
  # Writes an RGB image as PNG bytes, using only zlib from the standard library. The fake canvas
  # uses it for its PNG output, so the Mac needs no image gem.
  #
  # @example
  #   png = NhlScoreboard::PngEncoder.encode(2, 1, [255, 0, 0, 0, 0, 255].pack("C*"))
  #   File.binwrite("preview.png", png)
  class PngEncoder
    SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze

    # Encodes an image. Each row is filtered with type 0 (none), which keeps the encoder small.
    #
    # @param width [Integer] columns, at least 1.
    # @param height [Integer] rows, at least 1.
    # @param rgb [String] the pixels, row by row, three bytes each (red, green, blue).
    # @return [String] the PNG file's bytes, in binary encoding.
    # @raise [ArgumentError] if `rgb` isn't exactly `width * height * 3` bytes.
    # @example
    #   NhlScoreboard::PngEncoder.encode(1, 1, "\xFF\x00\x00".b).bytesize > 0 # => true
    def self.encode(width, height, rgb)
      expected = width * height * 3
      raise ArgumentError, "expected #{expected} bytes of RGB, got #{rgb.bytesize}" unless rgb.bytesize == expected

      stride = width * 3
      raw = +"".b
      height.times do |row|
        raw << "\x00".b << rgb.byteslice(row * stride, stride).b
      end

      header = [width, height, 8, 2, 0, 0, 0].pack("NNCCCCC")
      SIGNATURE + chunk("IHDR", header) + chunk("IDAT", Zlib::Deflate.deflate(raw)) + chunk("IEND", "")
    end

    # Builds one PNG chunk: length, type, data and a CRC over type and data.
    #
    # @api private
    def self.chunk(type, data)
      [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")
    end
    private_class_method :chunk
  end
end
