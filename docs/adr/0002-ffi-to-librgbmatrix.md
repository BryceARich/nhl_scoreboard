# 0002. Bind librgbmatrix with Ruby FFI, loaded at runtime

- **Status:** Proposed
- **Date:** 2026-11-24
- **Issue:** #2

## Context

The panels are driven by hzeller's `rpi-rgb-led-matrix`, which is C++ with a C API
(`include/led-matrix-c.h`). The app is Ruby, so something has to call that C API. The library is
built from source on the Pi (docs/RESUME.md), and the app must still load and run its specs on a
Mac that has no library. CLAUDE.md asks us to check that anything native installs on a Raspberry
Pi before we add it.

## Decision

We will use the `ffi` gem to bind the C functions we need (matrix, canvas, font) and load
`librgbmatrix` lazily with `ffi_lib` on first use. Only `lib/nhl_scoreboard/native.rb` and its
struct files touch C. The rest of the app sees `Matrix`, `Canvas` and `Font`.

`ffi` needs `libffi-dev` on the Pi, which docs/RESUME.md already lists. Our struct layouts are
written by hand from the header pinned in docs/RESUME.md. We checked them against that header
with the system C compiler (offset and size of every field), and the same check should be rerun
whenever the pin moves.

## Alternatives considered

- **A C extension built with `mkmf`.** Our own compiled code, linked against librgbmatrix. Rejected
  because it adds a build step to `bin/setup` on the Pi, needs the library's headers at gem
  install time, and gives us C to maintain for a binding that is only a dozen functions.
- **Shell out to a C helper per frame.** A small program that reads frames on stdin. Rejected:
  a process per session and per frame costs latency, and the library's vsync swap is best called
  from one long-lived process.
- **Port the driver to Ruby.** Rejected: the timing-sensitive GPIO driver is the library's work,
  and rewriting it would be a project of its own.

## Consequences

- No C compiler is needed for this app, and specs run on a Mac without the library.
- Loading the library happens on the first `Matrix.open`, which raises `NhlScoreboard::Error`
  with a pointer to the build steps when the library is missing.
- Struct layouts are a manual copy of the C header. A pin change needs the offset check above, and
  a follow-up may script it.
- The FFI calls aren't exercised by specs; the panel check (`bin/hello_panels`) is the test that
  matters. Until the maintainer runs it on the Pi, the binding is unverified on hardware.
