module Cryngine
  module Map
    class Sheet
      class_getter offset_x : Int64
      class_getter offset_y : Int64
      class_getter width : Int32
      class_getter height : Int32
      @@offset_y = uninitialized Int64
      @@offset_x = uninitialized Int64
      @@width = uninitialized Int32
      @@height = uninitialized Int32
      property texture : SDL::Texture
      @texture = uninitialized SDL::Texture

      @@scaled_width : Int64
      @@scaled_height : Int64
      @@scaled_width = uninitialized Int64
      @@scaled_height = uninitialized Int64
      getter col : Int16
      getter row : Int16

      class_getter sheets : Hash(Int16, Hash(Int16, Map::Sheet))
      @@sheets = {} of Int16 => Hash(Int16, Map::Sheet)

      def width
        self.class.width
      end

      def height
        self.class.height
      end

      def self.initialize(window, center_block : Block)
        @@width = window.width
        @@height = window.height
        @@offset_x = center_block.real_x
        @@offset_y = center_block.real_y
      end

      def self.sheet_from(block : Block)
        sheet_from(block.real_x, block.real_y)
      end

      def self.sheet_from(real_x : Int64, real_y : Int64)
        # puts "#{sheet_col(real_x)},#{sheet_row(real_y)} : #{real_x}, #{real_y}"
        col = sheet_col(real_x)
        row = sheet_row(real_y)
        Map::Sheet.sheets[col][row]
      end

      # def self.[](col, row)
      #   @@sheets[col][row]
      # rescue KeyError
      #   x_amount = (Player.unscaled_col * 2) * col
      #   y_amount = (Player.unscaled_row * 2) * row
      #   block = Map::Block.from_real (@@offset_x + x_amount).to_i64, (@@offset_y + y_amount).to_i64

      #   Display::SheetMaker.make_sheet col.to_i16, row.to_i16, block
      # end

      def initialize(@col, @row, texture : Pointer(LibSDL::Texture))
        @texture = SDL::Texture.new(texture)
        Map::Sheet.sheets[col] ||= {} of Int16 => Map::Sheet
        Map::Sheet.sheets[col][row] = self

        puts "Initialized Sheet #{col},#{row}"
      end

      def self.sheet_col(real_x)
        x1 = real_x * Map.tile_width * Map.scale
        offx = offset_x * Map.tile_width * Map.scale
        x = x1 - offx
        # puts "#{real_x}, #{x1}, #{x}, #{offx}"

        width = Player.pixels_width
        ((x + Map::Player.unscaled_pixels_col) / width).floor.to_i
      end

      def self.sheet_row(real_y)
        y = real_y * Map.tile_width * Map.scale
        offy = offset_y * Map.tile_width * Map.scale
        y -= offy
        # height = (Map::Player.unscaled_pixels_row * 2)
        height = Player.pixels_height
        ((y + Map::Player.unscaled_pixels_row) / height).floor.to_i
      end

      def self.scaled_width
        @@scaled_width = begin
          (width * Map.scale).to_i64
        end
      end

      def self.scaled_height
        @@scaled_height = begin
          (height * Map.scale).to_i64
        end
      end

      # def print_x_corner_from(real_x)
      #   x = real_x * Map.tile_width * Map.scale
      #   offx = self.class.offset_x * Map.tile_width * Map.scale
      #   x -= offx
      #   (col.to_i64 * Player.pixels_width) - Map::Player.unscaled_pixels_col - x + Map::Player.scaled_pixels_col - (Map.scaled_tile_width / 2).to_i
      # end

      # def print_y_corner_from(real_y)
      #   y = real_y * Map.tile_width * Map.scale
      #   offy = self.class.offset_y * Map.tile_width * Map.scale
      #   y -= offy
      #   (row.to_i64 * Player.pixels_height) - Map::Player.unscaled_pixels_row - y + Map::Player.scaled_pixels_row - (Map.scaled_tile_width / 2).to_i + Map::Player.player_height
      # end

      # def self.print_x_corner_from(real_x)
      #   -(Map::Player.unscaled_pixels_col - Map::Player.scaled_pixels_col) - ((Map.scaled_tile_width) / 2).to_i
      # end

      # def self.print_y_corner_from(real_y)
      #   -(Map::Player.unscaled_pixels_row - Map::Player.scaled_pixels_row) - ((Map.scaled_tile_height) / 2).to_i
      # end
    end
  end
end
