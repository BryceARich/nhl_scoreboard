# frozen_string_literal: true

require_relative "native/matrix_options"
require_relative "native/runtime_options"

module NhlScoreboard
  # The panel layout the scoreboard runs with, as the C library's options. The defaults are the
  # two-panel setup in docs/RESUME.md: 128×32 as four 32-column units, `regular` wiring and GPIO
  # slowdown 2.
  #
  # @example
  #   settings = NhlScoreboard::MatrixSettings.new(gpio_slowdown: 3)
  #   settings.rows # => 32
  class MatrixSettings
    # @return [Integer] rows per panel (`--led-rows`).
    attr_reader :rows
    # @return [Integer] columns per 32-column unit (`--led-cols`).
    attr_reader :cols
    # @return [Integer] number of units daisy-chained (`--led-chain`).
    attr_reader :chain_length
    # @return [Integer] parallel chains on the Pi (`--led-parallel`).
    attr_reader :parallel
    # @return [String] hardware mapping name (`--led-gpio-mapping`).
    attr_reader :hardware_mapping
    # @return [Integer] GPIO slowdown; higher is safer on a fast Pi (`--led-slowdown-gpio`).
    attr_reader :gpio_slowdown

    # Builds settings. Every argument has the RESUME default, so `new` gives the real panels.
    #
    # @param rows [Integer] rows per panel.
    # @param cols [Integer] columns per 32-column unit.
    # @param chain_length [Integer] daisy-chained units; 4 × 32 columns is 128.
    # @param parallel [Integer] parallel chains on the Pi.
    # @param hardware_mapping [String] wiring name, `"regular"` for the RESUME wiring.
    # @param gpio_slowdown [Integer] GPIO slowdown, 0 for none.
    # @return [MatrixSettings] the settings.
    # @raise [Error] if a count is below 1 or the slowdown is negative.
    # @example
    #   NhlScoreboard::MatrixSettings.new.chain_length # => 4
    def initialize(rows: 32, cols: 32, chain_length: 4, parallel: 1,
      hardware_mapping: "regular", gpio_slowdown: 2)
      {rows: rows, cols: cols, chain_length: chain_length, parallel: parallel}.each do |name, value|
        raise Error, "#{name} must be at least 1, got #{value}" if value < 1
      end
      raise Error, "gpio_slowdown can't be negative, got #{gpio_slowdown}" if gpio_slowdown.negative?

      @rows = rows
      @cols = cols
      @chain_length = chain_length
      @parallel = parallel
      @hardware_mapping = hardware_mapping
      @gpio_slowdown = gpio_slowdown
    end

    # Width of the whole chain in pixels, `cols * chain_length`.
    #
    # @return [Integer] total columns, 128 with the defaults.
    # @example
    #   NhlScoreboard::MatrixSettings.new.width # => 128
    def width
      cols * chain_length
    end

    # The matrix options struct for `led_matrix_create_from_options_and_rt_options`.
    #
    # @return [Native::MatrixOptions] the filled struct; keep a reference to it while in use.
    # @example
    #   NhlScoreboard::MatrixSettings.new.native_options[:rows] # => 32
    def native_options
      Native::MatrixOptions.new.tap do |options|
        options[:rows] = rows
        options[:cols] = cols
        options[:chain_length] = chain_length
        options[:parallel] = parallel
        options.use_hardware_mapping(hardware_mapping)
      end
    end

    # The runtime options struct for `led_matrix_create_from_options_and_rt_options`.
    #
    # @return [Native::RuntimeOptions] the filled struct.
    # @example
    #   NhlScoreboard::MatrixSettings.new.native_runtime_options[:gpio_slowdown] # => 2
    def native_runtime_options
      Native::RuntimeOptions.new.tap do |options|
        options[:gpio_slowdown] = gpio_slowdown
        options[:do_gpio_init] = true
      end
    end
  end
end
