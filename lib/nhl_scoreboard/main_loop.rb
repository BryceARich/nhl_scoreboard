# frozen_string_literal: true

module NhlScoreboard
  # The scoreboard's loop (C1-06): reads the day's games, picks the boards with {GamePicker}, draws them with
  # {GameDisplay}, and sleeps until the next thing to do. It only decides when to read and what to
  # show; the data comes from +source+ and the drawing from +display+.
  #
  # - **Adaptive polling:** the next read comes after the shortest wait +poll_interval+ gives any
  #   game (for `SportsIngest::NHL::PollInterval.for`, 10 s while live, 60 s before the puck drops).
  #   With no game left to poll, it rereads every {IDLE_SECONDS}, which catches the next day's games.
  # - **A day of games (ADR 0029):** each read is the day's games, so a game that starts mid-run joins
  #   the rotation and its score shows on the next read. A final game holds its board for one dwell
  #   after it is first seen final, then leaves the rotation. With no game left to show, the boards
  #   go blank (the idle state) rather than keep the last frame.
  # - **Offline tolerance:** when a read fails, the loop keeps the last good games on the panels,
  #   retries after a backoff that doubles from {RETRY_SECONDS} up to {RETRY_MAX_SECONDS}, and
  #   logs the failure. It never exits on a read error (ADR 0007).
  # - **Scroll clock (C1-10):** the loop wakes every {SCROLL_SECONDS} and redraws, and the goal ticker
  #   moves one column per wake, so the text scrolls ten columns a second. Reads and rotation
  #   still follow their own times, not the wake-ups (ADR 0025).
  # - **Delay (C1-12, ADR 0030):** with +delay+, the boards show each read {DelayedGames} holds back, so
  #   a viewer whose TV feed is behind the game can line the scoreboard up with it. Polling still
  #   follows the newest read.
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
    # @param delay [Numeric] seconds to hold each read back before the boards show it (C1-12). The
    #   default 0 shows each read at once.
    # @raise [ArgumentError] if +delay+ is negative.
    # @example
    #   NhlScoreboard::MainLoop.new(source: -> { [] }, display: display, picker: picker,
    #     poll_interval: ->(_game) { 60 }, delay: 30)
    def initialize(source:, display:, picker:, poll_interval:,
      clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, logger: $stderr, delay: 0)
      @source = source
      @display = display
      @picker = picker
      @poll_interval = poll_interval
      @clock = clock
      @logger = logger
      @games = []
      @reads = DelayedGames.new(delay: delay)
      @finished_at = {}
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
      shown = @reads.at(now) || []
      remember_finals(shown, now)
      display.show(picker.boards(on_boards(shown, now), now: now), step: scroll_step(now))
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

    # Reads the games and sets when the next read is due. The read is kept for the boards (see
    # {DelayedGames}), and the newest one sets the polling. A failure keeps the last good games.
    #
    # @param now [Numeric] the current time.
    # @return [void]
    def read(now)
      @games = Array(source.call)
      @reads.record(now, @games)
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

    # Records when each final game was first shown final, and forgets games no longer shown, so a
    # rematch on a later day starts its dwell afresh. With no delay this is the read's time, as before.
    #
    # @param shown [Array<Object>] the games the boards are showing, from the delayed read.
    # @param now [Numeric] the current time.
    # @return [void]
    def remember_finals(shown, now)
      @finished_at = shown.select(&:final?).to_h { |game| [key(game), @finished_at.fetch(key(game), now)] }
    end

    # The games still in the rotation: a final game leaves once it has held its board for one dwell.
    #
    # @param shown [Array<Object>] the games on the delayed read.
    # @param now [Numeric] the current time.
    # @return [Array<Object>] the games the picker may choose from.
    def on_boards(shown, now)
      shown.reject { |game| game.final? && now - @finished_at.fetch(key(game)) >= picker.dwell }
    end

    # A game's identity across reads: the two teams' tri-codes. A day never has the same pair twice,
    # and the reads give new objects each time, so the object itself can't be the key.
    #
    # @param game [#home_team, #away_team] a game from the source.
    # @return [Array<String>] the home and away tri-codes.
    def key(game)
      [game.home_team.tri_code, game.away_team.tri_code]
    end
  end
end
