module Cryngine
  module Map
    struct Chunk
      class_getter width : UInt8 = 16.to_u8
      class_getter height : UInt8 = 16.to_u8
      getter data : Hash(UInt8, Hash(UInt8, Int16)) = Hash(UInt8, Hash(UInt8, Int16)).new
      getter x : Int16
      getter y : Int16

      def initialize(data, @x, @y)
        data.each_with_index do |sprite, i|
          next if sprite == 0
          col = (i % self.class.width).to_u8
          row = (i / self.class.width).to_u8
          @data[col] ||= Hash(UInt8, Int16).new
          @data[col][row] = sprite.to_i16
        end
      end
    end
  end
end
