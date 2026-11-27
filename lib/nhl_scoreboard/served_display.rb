# frozen_string_literal: true

module NhlScoreboard
  # The display the main loop draws to when it runs on the fake panels (`bin/fake_panels --live`):
  # each set of boards is drawn by a {GameDisplay}, and the frame it returns goes to a
  # {PreviewServer}, so the browser page shows what the real panels would. The loop calls it the
  # same way it calls the real display, with +show(boards, step:)+.
  #
  # @example
  #   served = NhlScoreboard::ServedDisplay.new(display: display, server: server, scale: 7)
  #   served.show([game], step: 0) # draws the frame and publishes it
  class ServedDisplay
    # @return [GameDisplay] draws the boards onto the fake matrix.
    attr_reader :display

    # @return [PreviewServer, #publish] the server the browser page reads frames from.
    attr_reader :server

    # @return [Integer] pixels per LED in the published PNG.
    attr_reader :scale

    # @param display [GameDisplay, #show] draws the boards and returns the canvas it drew.
    # @param server [PreviewServer, #publish] publishes a canvas as the page's frame.
    # @param scale [Integer] pixels per LED in the published PNG.
    # @example
    #   NhlScoreboard::ServedDisplay.new(display: display, server: server)
    def initialize(display:, server:, scale: 7)
      @display = display
      @server = server
      @scale = scale
    end

    # Draws the boards and publishes the frame.
    #
    # @param boards [Array<Object>] the games to show, first board first; may be empty to blank the boards.
    # @param step [Integer] the goal ticker's scroll step, passed on to the display.
    # @return [void]
    # @example
    #   served.show([], step: 0) # blanks the boards
    def show(boards, step: 0)
      server.publish(display.show(boards, step: step), scale: scale)
    end
  end
end
