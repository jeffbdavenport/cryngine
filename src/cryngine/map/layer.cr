require "./chunk"

module Cryngine
  module Map
    struct Layer
      getter name : String
      getter visible : Bool
      getter startx : Int32
      getter starty : Int32
      getter x : Int32
      getter y : Int32
      getter chunks : Array(Chunk) = [] of Chunk

      def initialize(@name, @visible, @startx, @starty, @x, @y, chunks)
        chunks.as_a.each do |chunk|
          data = chunk["data"].as_a.map(&.as_i.to_i)
          # data = StaticArray(UInt8, 256).new(0)
          # array.each_with_index do |e, i|
          #   data[i] = e
          # end
          @chunks.push Chunk.new(
            data: data,
            x: (chunk["x"].as_i / Chunk.width).to_i16,
            y: (chunk["y"].as_i / Chunk.height).to_i16
          )
        end
      end
    end
  end
end
