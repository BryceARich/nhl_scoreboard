# frozen_string_literal: true

source "https://rubygems.org"

# FFI binds the librgbmatrix C API (ADR 0002). It builds on the Pi with libffi-dev (docs/RESUME.md).
gem "ffi", "~> 1.17"

# sports_ingest reads the NHL (ADR 0007). It isn't on RubyGems, so it comes from its public repo,
# pinned to a commit. It's pure Ruby and needs nothing native, so it installs on the Pi.
gem "sports_ingest", git: "https://github.com/BryceARich/sports_ingest.git",
  ref: "8b5d905566bf52ee300a6e69c76838b9f0168b0e"

# Specs and lint. They run offline and never need the panels.
group :development, :test do
  gem "rspec", "~> 3.13"
  gem "standard", "~> 1.40"
end
