require "json"
require "./map/tileset"
require "./map/layer"

module Cryngine
  module Map
    class_property path = "tiled/maps/"

    class_property tilesets : Hash(String, Tileset) = {} of String => Tileset
    class_property layers : Hash(Int32, Layer) = {} of Int32 => Layer
    class_property tile_height : Int32
    class_property tile_width : Int32

    @@tile_height = uninitialized Int32
    @@tile_width = uninitialized Int32
    class_getter isometric = true
    class_property scale = 1.0

    def self.scaled_tile_width
      (tile_width * scale).to_i
    end

    def self.scaled_tile_height
      (tile_height * scale).to_i
    end

    def self.load_map(name : String)
      json = File.open("#{path}#{name}.json") do |file|
        JSON.parse(file)
      end
      raise "Not a map" unless json["type"] == "map"
      @@isometric = false if json["orientation"] != "isometric"
      json["tilesets"].as_a.each do |tileset|
        if tileset["source"]?
          source = tileset["source"].as_s
          tileset_json = File.open("#{Map.path}#{source}") do |file|
            JSON.parse(file)
          end
          raise "Not a tileset" unless tileset_json["type"] == "tileset"
        else
          tileset_json = tileset
        end
        tileset = Tileset.new(tileset_json, tileset["firstgid"].as_i)
        @@tilesets[tileset.name] = tileset
      end
      json["layers"].as_a.each do |layer|
        next unless layer["chunks"]?
        @@layers[layer["id"].as_i] = Layer.new(
          name: layer["name"].as_s,
          visible: layer["visible"].as_bool,
          chunks: layer["chunks"],
          startx: layer["startx"].as_i,
          starty: layer["starty"].as_i,
          x: layer["x"].as_i,
          y: layer["y"].as_i
        )
      end
      @@tile_width = json["tilewidth"].as_i
      @@tile_height = json["tileheight"].as_i
    end

    def self.get_tileset(id)
      tilesets.each do |name, tileset|
        if id >= tileset.firstgid && id < tileset.firstgid + (tileset.tile_count)
          return tileset
        end
      end
      raise "Unknown tileset for tile: #{id}"
    end
  end
end
