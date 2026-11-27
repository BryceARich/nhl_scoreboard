# frozen_string_literal: true

module NhlScoreboard
  # The scoreboard's loop (C1-06): reads the day's games, picks the boards with {GamePicker}, draws them with
  # {GameDisplay}, and sleeps until the next thing to do. It only decides when to read and what to
  # show; the data comes from +source+ and the drawing from +display+.
  #
  # - **Adaptive polling:** the next read comes after the shortest wait +poll_interval+ gives any
  #   game (for `SportsIngest::NHL::PollInterval.for`, 10 s while live, 60 s before the puck drops).
  #   With no game left to poll, it rereads every {IDLE_SECONDS}, which catches the next day's games.
  # - **Offline tolerance:** when a read fails, the loop keeps the last good games on the panels,
  #   retries after a backoff that doubles from {RETRY_SECONDS} up to {RETRY_MAX_SECONDS}, and
  #   logs the failure. It never exits on a read error (ADR 0007).
  # - **Scroll clock (C1-10):** the loop wakes every {SCROLL_SECONDS} and redraws, and the goal ticker
  #   moves one column per wake, so the text scrolls ten columns a second. Reads and rotation
  #   still follow their own times, not the wake-ups (ADR 0025).
  # - **Unattended:** a Ruby error in drawing is not rescued; the process exits and its service
  #   manager restarts it (C1-07).
  #
  # @example
  #   loop = NhlScoreboard::MainLoop.new(
  #     source: -> { SportsIngest::NHL.scores },
  #     display: display, picker: NhlScoreboard::GamePicker.new(favorite: "COL"),
  #     poll_interval: ->(game) { SportsIngest::NHL::PollInterval.for(game) }
  #   )
  #   loop.run
  class MainLoop
    # @return [Integer] seconds between reads when no game needs polling (all final, or none today).
    IDLE_SECONDS = 300

    # @return [Integer] seconds before the first retry after a failed read.
    RETRY_SECONDS = 5

    # @return [Integer] the longest wait between retries while the source stays down.
    RETRY_MAX_SECONDS = 300

    # @return [Float] seconds between wake-ups, and so between draws: the goal ticker scrolls one
    #   column per wake. The same rate as `bin/fake_panels --demo ticker`.
    SCROLL_SECONDS = 0.1

    # @return [#call] returns the day's games, such as `-> { SportsIngest::NHL.scores }`.
    attr_reader :source

    # @return [GameDisplay] draws the chosen game.
    attr_reader :display

    # @return [GamePicker] chooses the game to show.
    attr_reader :picker

    # @param source [#call] returns the day's games (an Array of game objects); raises on failure.
    # @param display [GameDisplay, #show] draws the boards with +show(boards, step:)+, where +step+ is the ticker's scroll step.
    # @param picker [GamePicker] chooses which game to show.
    # @param poll_interval [#call] given a game, returns seconds until it should be read again, or
    #   nil when it needs no more reads.
    # @param clock [#call] returns the current time in seconds, monotonic.
    # @param logger [IO, #puts] where read failures are reported.
    # @example
    #   NhlScoreboard::MainLoop.new(source: -> { [] }, display: display, picker: picker,
    #     poll_interval: ->(_game) { 60 })
    def initialize(source:, display:, picker:, poll_interval:,
      clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, logger: $stderr)
      @source = source
      @display = display
      @picker = picker
      @poll_interval = poll_interval
      @clock = clock
      @logger = logger
      @games = []
      @next_read_at = nil
      @failures = 0
    end

    # Runs {#tick} forever, sleeping between ticks. Stop it with Ctrl-C or a signal.
    #
    # @param sleeper [#call] sleeps for the given seconds; a test can pass one that records them.
    # @return [void]
    # @example
    #   loop.run
    def run(sleeper: Kernel.method(:sleep))
      loop { sleeper.call(tick(@clock.call)) }
    end

    # One pass: read the games if one is due, draw the games the picker chooses with the ticker's
    # scroll step, and say how long to sleep before the next pass.
    #
    # @param now [Numeric] the current time, on the same clock as +clock+. The first call starts the
    #   scroll clock.
    # @return [Float] seconds to sleep: {SCROLL_SECONDS}.
    # @example
    #   loop.tick(0) # => 0.1
    def tick(now)
      @scroll_started_at ||= now
      read(now) if @next_read_at.nil? || now >= @next_read_at
      boards = picker.boards(@games, now: now)
      display.show(boards, step: scroll_step(now)) unless boards.empty?
      SCROLL_SECONDS
    end

    private

    # How far the goal ticker has scrolled: one column per {SCROLL_SECONDS} since the first tick.
    #
    # @param now [Numeric] the current time.
    # @return [Integer] the scroll step, in columns. Rounded before the floor, so float error
    #   (3 × 0.1 comes out just under 0.3) can't cost a column.
    def scroll_step(now)
      ((now - @scroll_started_at) / SCROLL_SECONDS).round(6).floor
    end

    # Reads the games and sets when the next read is due. A failure keeps the last good games.
    #
    # @param now [Numeric] the current time.
    # @return [void]
    def read(now)
      @games = Array(source.call)
      @failures = 0
      @next_read_at = now + next_poll_seconds
    rescue => e
      @failures += 1
      wait = [RETRY_SECONDS * 2**(@failures - 1), RETRY_MAX_SECONDS].min
      @next_read_at = now + wait
      @logger.puts "scoreboard: read failed (#{e.class}: #{e.message}); keeping the last games, retry in #{wait}s"
    end

    # @return [Numeric] the shortest wait any game asks for, or {IDLE_SECONDS} when none does.
    def next_poll_seconds
      waits = @games.filter_map { |game| @poll_interval.call(game) }
      waits.empty? ? IDLE_SECONDS : waits.min
    end
  end
end
