# frozen_string_literal: true

require_relative "error"

module NhlScoreboard
  # A pure-Ruby reader and writer for binary PPM (P6) images with 8 bits per channel. The team logos
  # are stored this way, so no image gem is needed. It needs no librgbmatrix either, so the Mac and
  # the Pi read the same files.
  #
  # @example
  #   logo = NhlScoreboard::PpmImage.load("assets/logos/avalanche.ppm")
  #   logo.width # => 20
  #   logo.draw(canvas, 54, 6)
  class PpmImage
    # Matches a P6 header: the magic, width, height and maxval, with `#` comments allowed between
    # fields. One whitespace byte follows maxval, and the pixel data starts after it.
    # The colour that means "transparent". P6 has no alpha channel, so a logo keys out its
    # transparent pixels to this colour, and {#draw} skips them. No logo uses it for art.
    TRANSPARENT = [255, 0, 255].freeze

    HEADER = /\AP6\s+(?:#[^\n]*\n\s*)*(\d+)\s+(?:#[^\n]*\n\s*)*(\d+)\s+(?:#[^\n]*\n\s*)*(\d+)\s/

    # @return [Integer] the number of columns.
    attr_reader :width
    # @return [Integer] the number of rows.
    attr_reader :height

    # Reads a binary PPM file.
    #
    # @param path [String] path to the `.ppm` file.
    # @return [PpmImage] the decoded image.
    # @raise [Error] if the file doesn't exist, isn't a P6 image with maxval 255, or is truncated.
    # @example
    #   NhlScoreboard::PpmImage.load("assets/logos/avalanche.ppm")
    def self.load(path)
      raise Error, "image file not found: #{path}" unless File.file?(path)

      parse(File.binread(path), path)
    end

    # Decodes the bytes of a binary PPM image. Used by {.load}; exposed so specs can decode a string.
    #
    # @param bytes [String] the whole file's bytes.
    # @param source [String] a name for error messages.
    # @return [PpmImage] the decoded image.
    # @raise [Error] if the header is not P6 with maxval 255, or the pixel data is short.
    # @example
    #   NhlScoreboard::PpmImage.parse("P6\n1 1\n255\n\xFF\x00\x00".b, "red.ppm")
    def self.parse(bytes, source = "PPM")
      bytes = bytes.b
      match = HEADER.match(bytes)
      raise Error, "#{source} is not a binary PPM (P6) image" unless match

      width, height, maxval = match.captures.map(&:to_i)
      raise Error, "#{source} must have maxval 255, not #{maxval}" unless maxval == 255
      raise Error, "#{source} has no pixels" if width.zero? || height.zero?

      size = width * height * 3
      data = bytes.byteslice(match.end(0), size)
      raise Error, "#{source} is truncated" unless data && data.bytesize == size

      new(width, height, data)
    end

    # Builds an image from raw pixel data.
    #
    # @param width [Integer] columns, at least 1.
    # @param height [Integer] rows, at least 1.
    # @param data [String] `width * height * 3` bytes of RGB, row by row, top left first.
    # @return [PpmImage] the image.
    # @raise [Error] if the data is not exactly `width * height * 3` bytes.
    # @example
    #   NhlScoreboard::PpmImage.new(1, 1, "\xFF\x00\x00".b)
    def initialize(width, height, data)
      bytes = data.b
      unless bytes.bytesize == width * height * 3
        raise Error, "image data must be #{width * height * 3} bytes, not #{bytes.bytesize}"
      end

      @width = width
      @height = height
      @data = bytes.freeze
    end

    # Reads one pixel.
    #
    # @param x [Integer] column, 0 at the left.
    # @param y [Integer] row, 0 at the top.
    # @return [Array<Integer>, nil] `[r, g, b]` at 0..255, or nil outside the image.
    # @example
    #   logo.pixel(0, 0) # => [0, 0, 0]
    def pixel(x, y)
      return nil unless x.between?(0, width - 1) && y.between?(0, height - 1)

      offset = (y * width + x) * 3
      @data.byteslice(offset, 3).bytes
    end

    # Draws every pixel onto a canvas, except {TRANSPARENT} pixels, which leave the canvas as it
    # was. The canvas clips anything outside its bounds.
    #
    # @param canvas [FakeCanvas, Canvas] any object with `set_pixel(x, y, r, g, b)`.
    # @param x [Integer] the canvas column of the image's left edge.
    # @param y [Integer] the canvas row of the image's top edge.
    # @return [nil]
    # @example
    #   logo.draw(canvas, 54, 6)
    def draw(canvas, x, y)
      height.times do |row|
        width.times do |column|
          color = pixel(column, row)
          next if color == TRANSPARENT

          canvas.set_pixel(x + column, y + row, *color)
        end
      end
      nil
    end

    # Makes a smaller copy by averaging each box of source pixels (box filter). Every output pixel
    # covers at least one source pixel, so sizes that don't divide evenly still work.
    #
    # @param new_width [Integer] columns of the copy, at least 1.
    # @param new_height [Integer] rows of the copy, at least 1.
    # @return [PpmImage] the resized copy; this image is unchanged.
    # @example
    #   full = NhlScoreboard::PpmImage.load("logo_128.ppm")
    #   small = full.resize_box(20, 20)
    def resize_box(new_width, new_height)
      out = String.new(encoding: Encoding::BINARY)
      new_height.times do |target_row|
        y0, y1 = span(target_row, new_height, height)
        new_width.times do |target_column|
          x0, x1 = span(target_column, new_width, width)
          out << average(x0, x1, y0, y1)
        end
      end
      self.class.new(new_width, new_height, out)
    end

    # Encodes the image as a binary PPM file.
    #
    # @return [String] the file's bytes.
    # @example
    #   File.binwrite("logo.ppm", image.to_ppm)
    def to_ppm
      "P6\n#{width} #{height}\n255\n".b + @data
    end

    private

    # The source range [start, stop) that one target pixel covers along an axis.
    def span(target, target_size, source_size)
      start = target * source_size / target_size
      stop = [((target + 1) * source_size) / target_size, start + 1].max
      [start, stop]
    end

    # The rounded mean of one box of source pixels, as three packed bytes.
    def average(x0, x1, y0, y1)
      sums = [0, 0, 0]
      count = 0
      (y0...y1).each do |y|
        (x0...x1).each do |x|
          offset = (y * width + x) * 3
          3.times { |channel| sums[channel] += @data.getbyte(offset + channel) }
          count += 1
        end
      end
      sums.map { |sum| (sum + count / 2) / count }.pack("C3")
    end
  end
end
