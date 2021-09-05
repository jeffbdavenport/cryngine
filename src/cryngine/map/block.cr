require "./chunk"

module Cryngine
  module Map
    struct Block
      getter x : Int16
      getter y : Int16
      getter col : UInt8
      getter row : UInt8

      def self.col(real_col)
        (real_col % Chunk.width).to_u8
      end

      def self.row(real_row)
        (real_row % Chunk.height).to_u8
      end

      def self.x(real_x)
        (real_x / Chunk.width).floor.to_i16
      end

      def self.y(real_y)
        (real_y / Chunk.height).floor.to_i16
      end

      def self.from_real(x : Int64, y : Int64)
        new(x(x), y(y), col(x), row(y))
      end

      def initialize(@x, @y, @col, @row)
      end

      def ==(other)
        x == other.x && y == other.y && col == other.col && row == other.row
      end

      def real_x
        (x.to_i64 * Chunk.width) + col
      end

      def real_y
        (y.to_i64 * Chunk.height) + row
      end

      # From the block being center of screen
      def screen_block_at(col, row)
      end

      def adjacent_from_block?(block, cols = 12, rows = 7)
        (block.real_x - real_x).abs <= cols && (block.real_y - real_y).abs <= rows
      end
    end
  end
end
