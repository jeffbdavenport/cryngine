module Cryngine
  module Map
    struct Frame
      getter cols : Int16
      getter rows : Int16
      getter width : Int16
      getter height : Int16
      getter pixels_width : Int16
      getter pixels_height : Int16
      getter width_remainder : Int16
      getter height_remainder : Int16
      getter tile_width : Int16
      getter tile_height : Int16

      def initialize(@width, @height, @tile_width : Int16, @tile_height : Int16)
        @cols = (width / tile_width).to_i16
        @rows = (height / tile_height).to_i16
        @pixels_width = (@cols * tile_width).to_i16
        @pixels_height = (@rows * tile_height).to_i16
        @width_remainder = (width % tile_width).to_i16
        @height_remainder = (height % tile_height).to_i16
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
