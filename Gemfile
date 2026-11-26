# frozen_string_literal: true

source "https://rubygems.org"

# FFI binds the librgbmatrix C API (ADR 0002). It builds on the Pi with libffi-dev (docs/RESUME.md).
gem "ffi", "~> 1.17"

# Specs and lint. They run offline and never need the panels.
group :development, :test do
  gem "rspec", "~> 3.13"
  gem "standard", "~> 1.40"
end
