# frozen_string_literal: true

require "json"

require_relative "error"
require_relative "game_state"

module NhlScoreboard
  # A recording of one game: the states read from the live feed, each with the time it was read.
  # It's a JSON Lines file, one snapshot per line. Each line is a {GameState} as {GameState#as_hash}
  # writes it, plus an `at` key with the read time in seconds since the epoch. A recording built from
  # a finished game's play-by-play (see {PlayByPlay}) uses game seconds for `at` instead. Recordings
  # belong outside the repo (ADR 0006).
  #
  # @example
  #   NhlScoreboard::GameRecording.append("games/2026-11-26-cbj-njd.jsonl", state, at: Time.now.to_f)
  #   NhlScoreboard::GameRecording.read("games/2026-11-26-cbj-njd.jsonl").size # => 1
  module GameRecording
    # One recorded read.
    #
    # @!attribute [r] at
    #   @return [Float] when the state was read, in seconds since the epoch.
    # @!attribute [r] state
    #   @return [GameState] the state read.
    Snapshot = Struct.new(:at, :state)

    # Adds one read to a recording, creating the file if it doesn't exist.
    #
    # @param path [String] the recording file.
    # @param state [GameState] the state read.
    # @param at [Numeric] when it was read, in seconds since the epoch.
    # @return [void]
    # @raise [Error] if `at` isn't a number.
    # @example
    #   NhlScoreboard::GameRecording.append("game.jsonl", state, at: 1_800_000_000.0)
    def self.append(path, state, at:)
      raise Error, "a snapshot's time must be a number of seconds, got #{at.inspect}" unless at.is_a?(Numeric)

      line = JSON.generate(state.as_hash.merge("at" => at.to_f))
      File.open(path, "a") { |file| file.puts(line) }
    end

    # Reads every snapshot in a recording, in the order they were written.
    #
    # @param path [String] the recording file.
    # @return [Array<Snapshot>] the snapshots, oldest first as the file has them.
    # @raise [Error] if the file isn't readable, or a line isn't a snapshot. The message names the
    #   line.
    # @example
    #   NhlScoreboard::GameRecording.read("game.jsonl").map(&:at)
    def self.read(path)
      File.readlines(path, chomp: true).each_with_index.filter_map do |line, index|
        next if line.strip.empty?

        parse(line, path, index + 1)
      end
    rescue SystemCallError => e
      raise Error, "cannot read recording #{path}: #{e.message}"
    end

    # @api private
    # @param line [String] one line of the file.
    # @param path [String] the file, for the message.
    # @param number [Integer] the line's number, for the message.
    # @return [Snapshot]
    # @raise [Error] if the line isn't JSON, or isn't a snapshot.
    def self.parse(line, path, number)
      data = JSON.parse(line)
      at = data.delete("at")
      raise Error, "#{path}:#{number} has no read time (\"at\")" unless at.is_a?(Numeric)

      Snapshot.new(at.to_f, GameState.from_h(data))
    rescue JSON::ParserError => e
      raise Error, "#{path}:#{number} is not valid JSON: #{e.message}"
    rescue Error => e
      raise Error, "#{path}:#{number}: #{e.message}"
    end

    private_class_method :parse
  end
end
