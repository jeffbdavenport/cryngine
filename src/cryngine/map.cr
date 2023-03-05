require "json"
require "./map/tileset"
require "./map/layer"
require "./map/collision_map"
require "./map/collider"
require "./display/renderer"

module Cryngine
  class Map
    class_property path = "tiled/maps/"

    setter path
    @path : String?

    getter tilesets : Hash(String, Tileset) = {} of String => Tileset
    getter layers : Hash(Int32, Layer) = {} of Int32 => Layer
    getter tile_height : UInt8
    getter tile_width : UInt8
    getter width : UInt16
    getter height : UInt16

    @tile_height = uninitialized UInt8
    @tile_width = uninitialized UInt8
    getter isometric = false
    getter scale = 1.0

    def scaled_tile_width
      (tile_width * scale).to_i
    end

    def scaled_tile_height
      (tile_height * scale).to_i
    end

    def path
      @path || self.class.path
    end

    def initialize(name : String, @scale : Float64)
      json = File.open("#{path}#{name}.json") do |file|
        JSON.parse(file)
      end
      raise "Not a map" unless json["type"] == "map"
      @isometric = json["orientation"] == "isometric"
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
        @tilesets[tileset.name] = tileset
      end
      json["layers"].as_a.each do |layer|
        next unless layer["chunks"]? && !layer["chunks"].as_a.empty?
        @layers[layer["id"].as_i] = Layer.new(
          name: layer["name"].as_s,
          visible: layer["visible"].as_bool,
          chunks: layer["chunks"],
          startx: layer["startx"].as_i,
          starty: layer["starty"].as_i,
          x: layer["x"].as_i,
          y: layer["y"].as_i
        )
      end
      @tile_width = json["tilewidth"].as_i.to_u8
      @tile_height = json["tileheight"].as_i.to_u8
      @width = 0
      @height = 0
      # @width = json["width"].as_i.to_u16
      # @height = json["height"].as_i.to_u16
    end

    def get_tileset(id)
      tilesets.each do |name, tileset|
        if id >= tileset.firstgid && id < tileset.firstgid + (tileset.tile_count)
          return tileset
        end
      end
      raise "Unknown tileset for tile: #{id}"
    end
  end
end
