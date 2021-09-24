require "./coord"
require "json"

module Cryngine
  class Map
    class Tileset
      class_property path = "./tiled/tilesets/"

      getter texture : SDL::Texture

      getter firstgid : Int32
      getter image : String

      getter name : String

      # How many columns in the Tileset png
      getter columns : Int32

      # Tileset png height in pixels
      getter height : Int32

      # Tileset width in pixels
      getter width : Int32

      # Pixel margin bordering tileset
      getter margin : Int32

      # Number of pixels between each sprite
      getter spacing : Int32

      # Number of tiles in tileset
      getter tile_count : Int32

      # Number of tiles high
      getter tile_height : Int32

      # Number of tiles wide
      getter tile_width : Int32

      getter transparenet_color : String

      getter tile_offset : Coord = Coord.new

      def initialize(json : JSON::Any, @firstgid : Int32 = 1)
        @image = "#{@@path}#{json["image"]}"
        @columns = json["columns"].as_i
        @height = json["imageheight"].as_i
        @width = json["imagewidth"].as_i
        @margin = json["margin"].as_i
        @name = json["name"].as_s
        @spacing = json["spacing"].as_i
        @tile_count = json["tilecount"].as_i
        @tile_height = json["tileheight"].as_i
        @tile_width = json["tilewidth"].as_i
        @transparenet_color = json["transparentcolor"].as_s
        if json["tileoffset"]?
          @tile_offset = Coord.new(x: json["tileoffset"]["x"].as_i, y: json["tileoffset"]["y"].as_i)
        end
        # May slow down due to blocking
        @texture = Renderer.load_texture @image
      end
    end
  end
end

#  "columns":16,
#  "imageheight":1344,
#  "imagewidth":1024,
#  "margin":0,
#  "name":"grassland",
#  "spacing":0,
#  "tilecount":672,
#  "tileheight":32,
#  "tilewidth":64,
#  "transparentcolor":"#ff00ff",
