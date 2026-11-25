# frozen_string_literal: true

require "ffi"

module NhlScoreboard
  module Native
    # C struct `RGBLedMatrixOptions` from `led-matrix-c.h`. Field order and types must match the
    # header at the commit pinned in docs/RESUME.md. Unset numeric fields stay zero, which the
    # library reads as its default.
    class MatrixOptions < FFI::Struct
      layout :hardware_mapping, :pointer,
        :rows, :int,
        :cols, :int,
        :chain_length, :int,
        :parallel, :int,
        :pwm_bits, :int,
        :pwm_lsb_nanoseconds, :int,
        :pwm_dither_bits, :int,
        :brightness, :int,
        :scan_mode, :int,
        :row_address_type, :int,
        :multiplexing, :int,
        :disable_hardware_pulsing, :bool,
        :show_refresh_rate, :bool,
        :inverse_colors, :bool,
        :led_rgb_sequence, :pointer,
        :pixel_mapper_config, :pointer,
        :panel_type, :pointer,
        :limit_refresh_rate_hz, :int,
        :disable_busy_waiting, :bool

      # Points `hardware_mapping` at a C string, such as `"regular"`. The Ruby buffer is kept on
      # this struct so it stays alive while the library reads it.
      #
      # @param name [String] the hardware mapping name, as `--led-gpio-mapping` takes it.
      # @return [String] the name that was set.
      # @example
      #   options = NhlScoreboard::Native::MatrixOptions.new
      #   options.use_hardware_mapping("regular")
      def use_hardware_mapping(name)
        @hardware_mapping_buffer = FFI::MemoryPointer.from_string(name)
        self[:hardware_mapping] = @hardware_mapping_buffer
        name
      end
    end
  end
end
