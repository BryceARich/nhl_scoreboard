# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::BoardGrid do
  # Every board's rectangle, as [x, y, width, height], in index order.
  def rectangles(grid)
    (0...grid.boards).map do |index|
      x, y = grid.origin(index)
      [x, y, 64, 24]
    end
  end

  it "lays one board across a single row" do
    grid = described_class.new(boards: 1, columns: 1)
    expect([grid.rows, grid.width, grid.height]).to eq([1, 64, 32])
    expect(grid.origin(0)).to eq([0, 0])
    expect(grid.ticker_band(0)).to eq(described_class::Band.new(0, 24, 64, 8))
  end

  it "lays four boards in a single row of four" do
    grid = described_class.new(boards: 4, columns: 4)
    expect([grid.rows, grid.width, grid.height]).to eq([1, 256, 32])
    expect(rectangles(grid).map { |x, y, *| [x, y] }).to eq([[0, 0], [64, 0], [128, 0], [192, 0]])
    expect(grid.ticker_band(0).width).to eq(256)
  end

  it "lays four boards down one column" do
    grid = described_class.new(boards: 4, columns: 1)
    expect([grid.rows, grid.width, grid.height]).to eq([4, 64, 128])
    expect(rectangles(grid).map { |x, y, *| [x, y] }).to eq([[0, 0], [0, 32], [0, 64], [0, 96]])
    expect((0..3).map { |row| grid.ticker_band(row).width }).to eq([64, 64, 64, 64])
  end

  it "puts seven boards as four on top and three below, each row with its own ticker" do
    grid = described_class.new(boards: 7, columns: 4)
    expect([grid.rows, grid.width, grid.height]).to eq([2, 256, 64])
    expect(grid.boards_in_row(0)).to eq(0..3)
    expect(grid.boards_in_row(1)).to eq(4..6)
    expect(grid.origin(4)).to eq([0, 32])
    expect(grid.origin(6)).to eq([128, 32])
    expect(grid.ticker_band(0)).to eq(described_class::Band.new(0, 24, 256, 8))
    expect(grid.ticker_band(1)).to eq(described_class::Band.new(0, 56, 192, 8))
  end

  it "fills a 4 by 4 grid with the bottom right board missing" do
    grid = described_class.new(boards: 15, columns: 4)
    expect([grid.rows, grid.width, grid.height]).to eq([4, 256, 128])
    expect(grid.boards_in_row(3)).to eq(12..14)
    expect(grid.origin(14)).to eq([128, 96])
    expect(grid.ticker_band(3).width).to eq(192)
    expect { grid.origin(15) }.to raise_error(ArgumentError, /isn't in a grid of 15/)
  end

  it "never places two boards on the same origin" do
    grid = described_class.new(boards: 15, columns: 4)
    origins = (0...grid.boards).map { |index| grid.origin(index) }
    expect(origins.uniq.size).to eq(15)
  end

  it "makes a full grid from a canvas" do
    grid = described_class.for_canvas(width: 128, height: 32)
    expect([grid.boards, grid.columns, grid.rows]).to eq([2, 2, 1])
    big = described_class.for_canvas(width: 256, height: 64)
    expect([big.boards, big.columns, big.rows]).to eq([8, 4, 2])
  end

  it "rejects a canvas that holds no board" do
    expect { described_class.for_canvas(width: 63, height: 32) }.to raise_error(ArgumentError, /holds no boards/)
    expect { described_class.for_canvas(width: 128, height: 31) }.to raise_error(ArgumentError, /holds no boards/)
  end

  it "rejects counts that aren't positive Integers" do
    expect { described_class.new(boards: 0, columns: 1) }.to raise_error(ArgumentError, /boards/)
    expect { described_class.new(boards: 2, columns: 2.0) }.to raise_error(ArgumentError, /columns/)
  end

  it "rejects a row that isn't in the grid" do
    expect { described_class.new(boards: 2, columns: 2).ticker_band(1) }.to raise_error(ArgumentError, /row 1/)
  end
end
