# frozen_string_literal: true

require "yaml"

# Checks the wiring of .github/workflows/ci.yml without running it. The licensed-data guard's own
# behavior is in spec/script/licensed_data_guard_spec.rb.
RSpec.describe "CI workflow" do
  root = File.expand_path("..", __dir__)
  workflow = YAML.load_file(File.join(root, ".github/workflows/ci.yml"))

  def run_steps(job)
    job.fetch("steps").filter_map { |step| step["run"] }
  end

  it "runs on pull requests and on main" do
    # YAML 1.1 reads the bare `on:` key as the boolean true.
    triggers = workflow.fetch(true)

    expect(triggers).to include("pull_request")
    expect(triggers.dig("push", "branches")).to eq(["main"])
  end

  it "guards tracked files, and every commit in a pull request" do
    steps = run_steps(workflow.dig("jobs", "licensed-data"))

    expect(steps).to include("ruby script/licensed-data-guard --all")
    expect(steps.grep(/--range/)).to include(a_string_including("pull_request.base.sha"))
  end

  it "fetches full history so --range can read every commit" do
    checkout = workflow.dig("jobs", "licensed-data", "steps").find { |s| s["uses"].to_s.start_with?("actions/checkout") }

    expect(checkout.dig("with", "fetch-depth")).to eq(0)
  end

  it "runs specs and lint on Ubuntu ARM64 with the Ruby from .ruby-version" do
    job = workflow.dig("jobs", "specs-and-lint")
    setup = job.fetch("steps").find { |s| s["uses"].to_s.start_with?("ruby/setup-ruby") }

    expect(job["runs-on"]).to eq("ubuntu-24.04-arm")
    expect(setup.dig("with", "ruby-version-file")).to eq(".ruby-version")
    expect(run_steps(job)).to include("bundle exec rspec", "bundle exec standardrb")
  end
end
