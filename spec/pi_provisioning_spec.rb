# frozen_string_literal: true

require "open3"

# Checks the Pi service files and script/pi/provision without installing anything. The Pi itself
# is checked by hand (docs/RESUME.md, "Running on boot").
RSpec.describe "Pi provisioning" do
  root = File.expand_path("..", __dir__)
  unit = File.read(File.join(root, "deploy/nhl-scoreboard.service"))
  logrotate = File.read(File.join(root, "deploy/nhl-scoreboard.logrotate"))

  def directives(text)
    text.lines.map(&:strip).reject { |line| line.empty? || line.start_with?("#") || line.start_with?("[") }
  end

  it "starts after the network is up, and restarts however often it fails" do
    lines = directives(unit)

    expect(lines).to include("Wants=network-online.target", "After=network-online.target")
    expect(lines).to include("Restart=always", "StartLimitIntervalSec=0")
    expect(lines).to include("WantedBy=multi-user.target")
  end

  it "runs bin/scoreboard from the checkout with the Ruby and font filled in by provision" do
    exec_start = directives(unit).find { |line| line.start_with?("ExecStart=") }

    expect(exec_start).to eq("ExecStart=@RUBY@ bin/scoreboard @FONT@")
    expect(directives(unit)).to include("WorkingDirectory=@APP_DIR@", "EnvironmentFile=/etc/nhl-scoreboard.env")
  end

  it "appends to the log that logrotate rotates" do
    output = directives(unit).find { |line| line.start_with?("StandardOutput=") }

    expect(output).to eq("StandardOutput=append:/var/log/nhl-scoreboard/scoreboard.log")
    expect(logrotate).to include("/var/log/nhl-scoreboard/*.log {")
    expect(directives(logrotate)).to include("copytruncate", "daily")
  end

  it "has a provision script that parses and refuses to run as root" do
    script = File.join(root, "script/pi/provision")
    stdout, stderr, status = Open3.capture3("bash", "-n", script)

    expect(status).to be_success, stderr
    expect(stdout).to be_empty
    expect(File.executable?(script)).to be(true)
    expect(File.read(script)).to include("if [ \"$(id -u)\" -eq 0 ]; then")
  end
end
