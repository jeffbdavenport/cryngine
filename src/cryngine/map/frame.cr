module Cryngine
  class Map
    struct Frame
      getter cols : UInt16
      getter rows : UInt16
      getter width : Int16 | Int32
      getter height : Int16 | Int32
      getter pixels_width : UInt32
      getter pixels_height : UInt32
      getter width_remainder : UInt16
      getter height_remainder : UInt16
      getter tile_width : UInt8
      getter tile_height : UInt8

      def initialize(@width, @height, @tile_width : UInt8, @tile_height : UInt8)
        @cols = (width / tile_width).to_u16
        @rows = (height / tile_height).to_u16
        @pixels_width = (@cols.to_u32 * tile_width)
        @pixels_height = (@rows.to_u32 * tile_height)
        @width_remainder = (width.to_u16 % tile_width)
        @height_remainder = (height.to_u16 % tile_height)
      end

      def half_tile_width
        (@tile_width / 2).to_i
      end

      def half_tile_height
        (@tile_width / 2).to_i
      end

      def size
        @cols * @rows
      end
    end
  end
end
