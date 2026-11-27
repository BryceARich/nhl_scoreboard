# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

# Fakes for the served display: a server that records published frames, and a display that records draws.
module ServedFakes
  class RecordingServer
    attr_reader :published

    def initialize
      @published = []
    end

    def publish(canvas, scale: 7)
      @published << [canvas, scale]
    end
  end

  # Draws nothing; returns a canvas marker and records the boards and step it was given.
  class RecordingDisplay
    attr_reader :calls

    def initialize
      @calls = []
    end

    def show(boards, step: 0)
      @calls << [boards, step]
      "canvas for #{boards.size} boards"
    end
  end
end

RSpec.describe NhlScoreboard::ServedDisplay do
  let(:server) { ServedFakes::RecordingServer.new }
  let(:display) { ServedFakes::RecordingDisplay.new }
  let(:served) { described_class.new(display: display, server: server, scale: 5) }

  it "draws the boards and publishes the frame it returns, at the scale" do
    served.show(%w[a b], step: 3)
    expect(display.calls).to eq([[%w[a b], 3]])
    expect(server.published).to eq([["canvas for 2 boards", 5]])
  end

  it "publishes a blank frame when there are no boards" do
    served.show([])
    expect(display.calls).to eq([[[], 0]])
    expect(server.published).to eq([["canvas for 0 boards", 5]])
  end

  it "defaults the scale to 7 pixels per LED" do
    described_class.new(display: display, server: server).show(["x"])
    expect(server.published.last.last).to eq(7)
  end
end
