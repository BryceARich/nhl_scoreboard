# frozen_string_literal: true

require_relative "error"
require_relative "ppm_image"

module NhlScoreboard
  # The team logos, already pre-sized to 20×20 and stored under `assets/logos/`. Each logo is
  # named after its file, without `.ppm`, so `avalanche` is `assets/logos/avalanche.ppm`. Made by
  # `script/import_logos` from the pixelated logos in NHL_Apps.
  #
  # @example
  #   logos = NhlScoreboard::LogoLibrary.load
  #   logos.fetch("avalanche").draw(canvas, 54, 6)
  module LogoLibrary
    # @return [String] the committed logo directory, absolute.
    DIRECTORY = File.expand_path("../../assets/logos", __dir__)

    # Reads every `.ppm` file in a directory.
    #
    # @param directory [String] the directory to read.
    # @return [Hash{String => PpmImage}] logo name to image, sorted by name.
    # @raise [Error] if the directory doesn't exist or a file is not a valid P6 image.
    # @example
    #   NhlScoreboard::LogoLibrary.load.keys.first # => "avalanche"
    def self.load(directory = DIRECTORY)
      raise Error, "logo directory not found: #{directory}" unless File.directory?(directory)

      Dir.glob(File.join(directory, "*.ppm")).sort.to_h do |path|
        [File.basename(path, ".ppm"), PpmImage.load(path)]
      end
    end
  end
end
