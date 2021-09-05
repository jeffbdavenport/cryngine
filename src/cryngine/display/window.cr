require "magickwand-crystal"
require "sdl"
require "sdl/lib_img"
require "../map/tile"
require "../event"
require "./dither_tool"
require "../map/block"
require "../map/player"
require "../map/sheet"
require "../display/sheet_maker"

macro define_pixelformat(type, order, layout, bits, bytes)
 ((1 << 28) | ({{type}} << 24) | ({{order}} << 20) | ({{layout}} << 16) | ({{bits}} << 8) | ({{bytes}} << 0))
end

module Cryngine
  module Display
    module Window
      include SDL
      class_getter window : Window
      class_getter renderer : Renderer
      class_getter surface : Pointer(LibSDL::Surface)
      class_getter textures = {} of String => Pointer(LibSDL::Texture)
      @@window = uninitialized Window
      @@renderer = uninitialized Renderer
      @@surface = uninitialized Pointer(LibSDL::Surface)
      WIDTH           = 1800
      HEIGHT          = 1000
      BIT_DEPTH       =   24
      BMP_HEADER_SIZE =   54

      def self.initialize(game_title : String)
        Cryngine::Event.initialize
        Devices::Keyboard.initialize

        LibIMG.init LibIMG::Init::PNG

        @@window = Window.new(game_title, WIDTH, HEIGHT)
        @@renderer = Renderer.new(window)
        renderer.clear
        player_rect = Rect.new(((window.width / 2) - 60).to_i, ((window.height / 2) - 71).to_i, 120, 142)
        player_texture = load_img_texture "assets/sprites/full/models/male_redone_OC.png"

        Map.tilesets.each do |name, tileset|
          textures[name] = load_img_texture tileset.image
        end

        Map::Player.initialize(window, 7, -17)
        Map::Sheet.initialize(window, Map::Player.block)
        puts "Player: #{Map::Player.col}, #{Map::Player.row}: #{Map::Player.block.real_x}, #{Map::Player.block.real_y}"

        @@surface = new_surface_as_render
        Display::SheetMaker.make_sheet 0.to_i16, 0.to_i16, Map::Player.block
        # tile = Map::Tile.new(start_x, start_y, sprite, chunk, 0, 0)
        # renderer.viewport = tile.viewport
        # renderer.copy(textures[tile.tileset.name], tile.clip)

        # Map.layers.keys.sort.each do |id|
        #   layer = Map.layers[id]
        #   layer.chunks.each do |chunk|
        #     chunk.data.keys.sort.each do |col|
        #       rows = chunk.data[col]
        #       rows.keys.sort.each do |row|
        #         block = Map::Block.new(chunk.x, chunk.y, col, row)
        #         sprite = rows[row]
        #         # next unless block.adjacent_from_block?(Map::Player.block)
        #         # puts "#{x}, #{y}"
        #         tile = Map::Tile.new(col, row, sprite, chunk)
        #         # next if tile.outside_window?(window)

        #         rect = Rect.new(((window.width / 2) - 16).to_i, ((window.height / 2) - 16).to_i, 32, 32)
        #         renderer.viewport = rect
        #         renderer.copy(textures[tile.tileset.name], tile.clip)
        #         copies += 1
        #       end
        #     end
        #   end
        # end
        # renderer.viewport = player_rect
        # renderer.copy(player_texture)

        # (unused, w, h, bd, rmask, gmask, bmask, amask)
        # surface = LibSDL.create_rgb_surface(0, surf_width, surf_height, BIT_DEPTH, 0xff000000, 0x00ff0000, 0x0000ff00, 0)
        # LibSDL.free_surface surface

        while true
          sleep 400.milliseconds
          # renderer.clear

          Map::Player.move(-1, -1)
          # start_x += 3
          # start_y -= 1

          # x = Map::Sheet.print_x_corner_from(Map::Player.block.real_x)
          # y = Map::Sheet.print_y_corner_from(Map::Player.block.real_y)
          # puts "#{x}, #{y}"
          sheet = Map::Sheet.sheet_from(Map::Player.block)
          # [[0, -1], [-1, -1], [-1, 0], [1, 0], [0, 1], [1, 1], [-1, 1], [1, -1]].each do |pairs|
          #   spawn do
          #     Map::Sheet[sheet.col + pairs[0], sheet.row + pairs[1]]
          #     Fiber.yield
          #   end
          # end

          x = sheet.print_x_corner_from(Map::Player.block.real_x)
          y = sheet.print_y_corner_from(Map::Player.block.real_y)
          mwidth = (Map::Player.unscaled_pixels_col * 2).to_i
          mheight = (Map::Player.unscaled_pixels_row * 2).to_i

          clip_rect = Rect.new(0, 0, mwidth, mheight)
          rect = Rect.new(x.to_i, y.to_i, (window.width * Map.scale).to_i, (window.height * Map.scale).to_i)
          renderer.viewport = rect

          renderer.copy(sheet.texture, clip_rect)
          renderer.viewport = player_rect
          renderer.copy(player_texture)

          [[0, -1], [-1, -1], [-1, 0], [1, 0], [0, 1], [1, 1], [-1, 1], [1, -1]].each do |pairs|
            spawn do
              this_sheet = Map::Sheet[sheet.col + pairs[0], sheet.row + pairs[1]]
              x = this_sheet.print_x_corner_from(Map::Player.block.real_x)
              y = this_sheet.print_y_corner_from(Map::Player.block.real_y)
              rect = Rect.new(x.to_i, y.to_i, (window.width * Map.scale).to_i, (window.height * Map.scale).to_i)
              renderer.viewport = rect

              renderer.copy(this_sheet.texture, clip_rect)
              renderer.viewport = player_rect
              renderer.copy(player_texture)
              renderer.present
            end
          end
          renderer.viewport = player_rect
          renderer.copy(player_texture)

          renderer.present
        end

        SheetMaker.cleanup
      end

      def self.new_surface_as_render
        surface = LibSDL.create_rgb_surface(0, window.width, window.height, BIT_DEPTH, 0xff000000, 0x00ff0000, 0x0000ff00, 0)
        texture = LibSDL.create_texture_from_surface(renderer, surface)
        LibSDL.set_render_target renderer, texture
        surface
      end

      def self.copy_renderer_to_surface
        format = surface.value.format.value
        rect = Rect.new(0, 0, window.width, window.height)
        renderer.viewport = rect
        # nil is Rect for what to copy
        error = LibSDL.render_read_pixels(renderer, pointerof(rect), format.format, surface.value.pixels, surface.value.pitch)

        renderer.clear
        error = 0
        if error != 0
          SDL::Error.new("Could not read pixels:")
        end
      end

      def self.surface_as_bytes(surface)
        bytes_per_pixel = BIT_DEPTH / 8
        pixel_count = (window.width) * (window.height)
        bytesize = (pixel_count * bytes_per_pixel + BMP_HEADER_SIZE).to_i
        pixels = Bytes.new(bytesize) # 198)

        rw = LibSDL.rw_from_mem(pixels, pixels.size)
        LibSDL.save_bmp_rw(surface, rw, 1)
        pixels
      end

      def self.load_img_texture(path : String)
        surface = LibIMG.load path
        if !surface
          raise SDL::Error.new("Unable to load image") # {LibSDL.get_error.value}\n"
        end

        texture = LibSDL.create_texture_from_surface(renderer, surface)

        # puts texture.value.pixels

        LibSDL.free_surface surface
        texture
      end
    end
  end
end
