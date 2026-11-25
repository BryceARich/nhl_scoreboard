# frozen_string_literal: true

require "ffi"

module NhlScoreboard
  module Native
    # C struct `RGBLedRuntimeOptions` from `led-matrix-c.h`, at the commit pinned in
    # docs/RESUME.md. `daemon` and `drop_privileges` are 0 (off) here; `do_gpio_init` must be
    # set to true, because a zeroed bool would skip GPIO setup.
    class RuntimeOptions < FFI::Struct
      layout :gpio_slowdown, :int,
        :rp1_pio, :int,
        :daemon, :int,
        :drop_privileges, :int,
        :do_gpio_init, :bool,
        :drop_priv_user, :pointer,
        :drop_priv_group, :pointer
    end
  end
end
