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
        width = window.width   # - (Map.tile_width * 2)
        height = window.height # - (Map.tile_height * 2)
        @@col = ((width / (Map.tile_width * Map.scale)).to_i / 2.0)
        @@row = ((height / (Map.tile_height * Map.scale)).to_i / 2.0)
        @@unscaled_col = ((width / Map.tile_width).to_i / 2.0)
        @@unscaled_row = ((height / Map.tile_height).to_i / 2.0)
        # puts "#{@@col},#{@@row}:#{@@unscaled_col},#{@@unscaled_row}"
      end

      def self.move(col, row)
        # sheet = Sheet.sheet_from(@@block)
        @@block = Map::Block.from_real(block.real_x + col, block.real_y + row)

        SheetMaker.update_center_channel.send(@@block)
        # new_sheet = begin
        #   Sheet.sheet_from(@@block)
        # rescue KeyError
        #   nil
        # end
        # if sheet != new_sheet
        # Display::Window.map_checker_channel.send(nil)
        # end
        @@block
      end

      def self.pixels_col
        (col * Map.tile_width).to_i
      end

      def self.pixels_row
        (row * Map.tile_height).to_i
      end

      def self.pixels_width
        (unscaled_col * 2 * Map.tile_width * Map.scale).to_i
      end

      def self.pixels_height
        (unscaled_row * 2 * Map.tile_width * Map.scale).to_i
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
