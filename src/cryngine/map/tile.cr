require "sdl"
require "./tileset"

module Cryngine
  class Map
    struct Tile
      include SDL
      getter id : Int16
      getter tileset : Tileset
      getter chunk : Chunk
      getter row : UInt8
      getter col : UInt8
      getter map : Map

      def initialize(@map : Map, @col : UInt8, @row : UInt8, @id : Int16, @chunk : Chunk)
        @tileset = @map.get_tileset(id)
      end

      def self.clip(id, tileset : Tileset)
        id -= tileset.firstgid
        tilecol = (id.to_i % tileset.columns).to_i
        tilerow = (id.to_i / tileset.columns).to_i
        clip_x = (tilecol.to_i * tileset.tile_width).to_i
        clip_y = (tilerow.to_i * tileset.tile_height).to_i
        Rect.new(x: clip_x, y: clip_y, w: tileset.tile_width, h: tileset.tile_height)
      end

      def clip
        self.class.clip(@id, tileset)
      end

      # def viewport
      #   @viewport ||= begin
      #     # puts "#{chunk.x},#{chunk.y} #{x}, #{y}"
      #     Rect.new(*xy, tileset.tile_width, tileset.tile_height)
      #   end
      # end

      def xy
        Map.isometric ? isometric_xy : orthogonal_xy
      end

      # def x
      #   @x ||= begin
      #     col.to_i + (chunk.x * Chunk.width) + (tileset.tile_offset.x / Map.tile_width).to_i
      #   end
      # end

      # def y
      #   @y ||= begin
      #     row.to_i + (chunk.y * Chunk.height) + (tileset.tile_offset.y / Map.tile_height).to_i
      #   end
      # end

      # def width
      #   @width ||= begin
      #     (col.to_i * Map.tile_width) + (chunk.x * Chunk.width * Map.tile_width) + tileset.tile_offset.x
      #   end
      # end

      # def height
      #   @height ||= begin
      #     (row.to_i * Map.tile_height) + (chunk.y * Chunk.height * Map.tile_height) + tileset.tile_offset.y
      #   end
      # end

      # O O O
      # O O O
      # O O X
      # col: 2, row: 2

      # (2 * 80) - (2 * 80) + 0 - 0 + 0

      # def orthogonal_xy(offsetx = 0, offsety = 0)
      #   {width + @offsetx, height + @offsety}
      # end

      # def isometric_xy(offsetx = 0, offsety = 0)
      #   halfwidth = (Map.tile_width / 2).to_i
      #   halfheight = (Map.tile_height / 2).to_i
      #   x = (col.to_i * halfwidth) - (row.to_i * halfwidth) + (chunk.x * Chunk.width * halfwidth) - (chunk.y * Chunk.width * halfwidth) + tileset.tile_offset.x
      #   y = (col.to_i * halfheight) + (row.to_i * halfheight) + (chunk.x * Chunk.height * halfheight) + (chunk.y * Chunk.height * halfheight) - (tileset.tile_height - Map.tile_height) + tileset.tile_offset.y
      #   {x.to_i + offsetx, y.to_i + offsety}
      # end

      # def outside_window?(window : Window)
      #   viewport.x > window.width || viewport.x < -(tileset.tile_width * Map.scale).to_i || viewport.y > window.height || viewport.y < -(tileset.tile_width * Map.scale).to_i
      # end
    end
  end
end
