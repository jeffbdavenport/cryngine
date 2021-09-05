require "./block"
require "../map"

module Cryngine
  module Map
    module Player
      class_getter block : Block
      class_getter col : Float64
      class_getter row : Float64
      class_getter unscaled_col : Float64
      class_getter unscaled_row : Float64
      @@col = uninitialized Float64
      @@row = uninitialized Float64
      @@unscaled_col = uninitialized Float64
      @@unscaled_row = uninitialized Float64
      class_getter player_height : Int32 = 61

      @@block = uninitialized Block

      def self.initialize(window, real_x : Int64, real_y : Int64)
        @@block = Map::Block.from_real(real_x, real_y)
        @@col = ((window.width / (Map.tile_width * Map.scale)) / 2.0)
        @@row = ((window.height / (Map.tile_height * Map.scale)) / 2.0)
        @@unscaled_col = ((window.width / (Map.tile_width)) / 2.0).ceil
        @@unscaled_row = ((window.height / (Map.tile_height)) / 2.0).ceil
        puts "#{@@col},#{@@row}:#{@@unscaled_col},#{@@unscaled_row}"
      end

      def self.move(col, row)
        @@block = Map::Block.from_real(block.real_x + col, block.real_y + row)
      end

      def self.pixels_col
        (col * Map.tile_width).to_i
      end

      def self.pixels_row
        (row * Map.tile_height).to_i
      end

      def self.unscaled_pixels_col
        (unscaled_col * Map.tile_width * Map.scale).to_i
      end

      def self.unscaled_pixels_row
        (unscaled_row * Map.tile_height * Map.scale).to_i
      end

      def self.scaled_pixels_col
        (col * Map.tile_width * Map.scale).to_i
      end

      def self.scaled_pixels_row
        (row * Map.tile_height * Map.scale).to_i
      end
    end
  end
end
