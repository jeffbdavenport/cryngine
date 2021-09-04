require "sdl"

module Cryngine
  module Map
    struct Tile
      include SDL
      getter x : Int32
      getter y : Int32
      getter tileset : Tileset
      getter chunk : Chunk
      getter row : UInt8
      getter col : UInt8
      property offsetx : Int32
      property offsety : Int32

      def initialize(@col : UInt8, @row : UInt8, id, @chunk : Chunk, @offsetx, @offsety)
        @tileset = Map.get_tileset(id)
        before = id
        id -= tileset.firstgid
        tilecol = (id % tileset.columns).to_i
        tilerow = (id / tileset.columns).to_i
        @x = (tilecol * tileset.tile_width).to_i
        @y = (tilerow * tileset.tile_height).to_i
      end

      def clip
        @clip ||= begin
          Rect.new(x: x, y: y, w: tileset.tile_width, h: tileset.tile_height)
        end
      end

      def viewport
        @viewport ||= begin
          # puts "#{chunk.x},#{chunk.y} #{x}, #{y}"
          Rect.new(*xy, (tileset.tile_width * Map.scale).to_i, (tileset.tile_height * Map.scale).to_i)
        end
      end

      def xy
        Map.isometric ? isometric_xy : orthogonal_xy
      end

      # O O O
      # O O O
      # O O X
      # col: 2, row: 2

      # (2 * 80) - (2 * 80) + 0 - 0 + 0

      def orthogonal_xy(offsetx = 0, offsety = 0)
        x = (col.to_i * Map.tile_width) + (chunk.x * Chunk.width * Map.tile_width) + tileset.tile_offset.x
        # y = (row.to_i * Map.tile_height) + (chunk.y * Chunk.height * Map.tile_height) - (tileset.tile_height - Map.tile_height) + tileset.tile_offset.y
        y = (row.to_i * Map.tile_height) + (chunk.y * Chunk.height * Map.tile_height) + tileset.tile_offset.y
        tuple = {(x * Map.scale).to_i + @offsetx, (y * Map.scale).to_i + @offsety}
        # puts tuple
        tuple
        # {x + 100, y + 200}
      end

      def isometric_xy(offsetx = 0, offsety = 0)
        halfwidth = (Map.tile_width / 2).to_i
        halfheight = (Map.tile_height / 2).to_i
        x = (col.to_i * halfwidth) - (row.to_i * halfwidth) + (chunk.x * Chunk.width * halfwidth) - (chunk.y * Chunk.width * halfwidth) + tileset.tile_offset.x
        y = (col.to_i * halfheight) + (row.to_i * halfheight) + (chunk.x * Chunk.height * halfheight) + (chunk.y * Chunk.height * halfheight) - (tileset.tile_height - Map.tile_height) + tileset.tile_offset.y
        {x.to_i + offsetx, y.to_i + offsety}
      end

      def outside_window?(window : Window)
        viewport.x > window.width || viewport.x < -(tileset.tile_width * Map.scale).to_i || viewport.y > window.height || viewport.y < -(tileset.tile_width * Map.scale).to_i
      end
    end
  end
end
