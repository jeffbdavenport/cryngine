require "magickwand-crystal"
require "sdl"
require "sdl/lib_img"
require "../map/tile"

macro dEFINE_PIXELFOURCC(a, b, c, d)
 {{a}}.to_u32 << 0 |
 {{b}}.to_u32 << 8 |
 {{c}}.to_u32 << 16 |
 {{d}}.to_u32 << 24
end

macro define_pixelformat(type, order, layout, bits, bytes)
 ((1 << 28) | ({{type}} << 24) | ({{order}} << 20) | ({{layout}} << 16) | ({{bits}} << 8) | ({{bytes}} << 0))
end

module Cryngine
  module Display
    module Window
      include SDL
      class_getter window : Window
      @@window = uninitialized Window
      class_getter renderer : Renderer
      @@renderer = uninitialized Renderer
      LibMagick.magickWandGenesis # lib init
      @@wand = LibMagick.newMagickWand
      LibMagick.magickReadImage @@wand, "assets/color_palettes/OC.png"
      WIDTH           = 1800
      HEIGHT          = 1000
      BIT_DEPTH       =   24
      BMP_HEADER_SIZE =   54

      def self.initialize(game_title : String)
        LibSDL.event_state(LibSDL::EventType::MOUSE_MOTION, LibSDL::IGNORE)
        LibSDL.event_state(LibSDL::EventType::WINDOW_EVENT, LibSDL::IGNORE)
        # LibSDL.event_state(LibSDL::EventType::KEYDOWN, LibSDL::IGNORE)
        # LibSDL.event_state(LibSDL::EventType::KEYUP, LibSDL::IGNORE)
        LibSDL.event_state(LibSDL::EventType::TEXT_EDITING, LibSDL::IGNORE)
        LibSDL.event_state(LibSDL::EventType::TEXT_INPUT, LibSDL::IGNORE)
        LibSDL.event_state(LibSDL::EventType::MOUSE_BUTTON_UP, LibSDL::IGNORE)
        LibSDL.event_state(LibSDL::EventType::MOUSE_BUTTON_DOWN, LibSDL::IGNORE)
        LibSDL.event_state(LibSDL::EventType::MOUSE_WHEEL, LibSDL::IGNORE)
        LibSDL.event_state(LibSDL::EventType::USER_EVENT, LibSDL::IGNORE)
        LibSDL.event_state(LibSDL::EventType::SYS_WM_EVENT, LibSDL::IGNORE)
        spawn do
          loop do
            while e = Event.poll
              case e
              when SDL::Event::Quit
                exit
              end
            end
            sleep 80.milliseconds
          end
        end

        # @@window.fullscreen = true
        Devices::Keyboard.initialize
        # renderer.draw_color = Color[255]
        LibIMG.init LibIMG::Init::PNG

        start_x = 600
        start_y = 1000

        # bytes_per_pixel = BIT_DEPTH / 8
        # pixel_count = WIDTH * HEIGHT
        # bytesize = (pixel_count * bytes_per_pixel + BMP_HEADER_SIZE).to_i
        # pixels = Bytes.new(bytesize) # 198)

        # chunk_max_x = Map.layers[1].chunks.map(&.x).max
        # chunk_max_y = Map.layers[1].chunks.map(&.y).max
        # chunk_min_x = Map.layers[1].chunks.map(&.x).min
        # chunk_min_y = Map.layers[1].chunks.map(&.y).min
        # puts chunk_min_x
        # puts chunk_min_y
        # puts chunk_max_x
        # puts chunk_max_y
        # surf_width = ((chunk_max_x + chunk_min_x.abs) * Map::Chunk.width * Map.tile_width * Map.scale).to_i
        # surf_height = ((chunk_max_y + chunk_min_y.abs) * Map::Chunk.height * Map.tile_height * Map.scale).to_i
        # start_x = 0
        # start_y = 0

        @@window = Window.new(game_title, WIDTH, HEIGHT)
        # LibSDL.hide_window @@window
        @@renderer = Renderer.new(window)
        renderer.clear
        player_rect = Rect.new(((window.width / 2) - 60).to_i, ((window.height / 2) - 71).to_i, 120, 142)
        player_texture = load_img_texture "assets/sprites/full/models/male_redone_OC.png"
        # player_rect = Rect.new(0, 0, 1400, 900)
        # player_texture = load_img_texture "dithered_test.png"
        textures = {} of String => Pointer(LibSDL::Texture)
        Map.tilesets.each do |name, tileset|
          textures[name] = load_img_texture tileset.image
        end

        # if chunk_min_x.negative?
        #   start_x = (chunk_min_x.abs * Map::Chunk.width * Map.tile_width * Map.scale).to_i
        # end
        # if chunk_min_y.negative?
        #   start_y = (chunk_min_y.abs * Map::Chunk.width * Map.tile_width * Map.scale).to_i
        # end
        # puts surf_height
        # puts surf_width
        surface = LibSDL.create_rgb_surface(0, window.width, window.height, BIT_DEPTH, 0xff000000, 0x00ff0000, 0x0000ff00, 0)
        texture = LibSDL.create_texture_from_surface(renderer, surface)
        LibSDL.set_render_target renderer, texture

        Map.layers.keys.sort.each do |id|
          layer = Map.layers[id]
          layer.chunks.each do |chunk|
            chunk.data.keys.sort.each do |col|
              hash = chunk.data[col]
              hash.keys.sort.each do |row|
                sprite = hash[row]
                tile = Map::Tile.new(col, row, sprite, chunk, start_x, start_y)
                next if tile.outside_window?(window)

                renderer.viewport = tile.viewport
                renderer.copy(textures[tile.tileset.name], tile.clip)
              end
            end
          end
        end
        # renderer.viewport = player_rect
        # renderer.copy(player_texture)

        # surface = LibSDL.create_rgb_surface(0, surf_width, surf_height, BIT_DEPTH, 0xff000000, 0x00ff0000, 0x0000ff00, 0)
        format = surface.value.format.value
        # LibSDL.free_surface surface
        rect = Rect.new(0, 0, window.width, window.height)
        renderer.viewport = rect
        # nil is Rect for what to copy
        error = LibSDL.render_read_pixels(renderer, pointerof(rect), format.format, surface.value.pixels, surface.value.pitch)
        s = Surface.new(surface)
        s.save_bmp("dithered.bmp")
        puts `time convert -resize 4500x2500 -filter Box -remap assets/color_palettes/OC.png -dither Floyd-Steinberg dithered.bmp dithered.png`
        texture = load_img_texture("dithered.png")

        renderer.clear

        # error = 0
        # if error != 0
        #   SDL::Error.new("Could not read pixels: ")
        # end
        # SDL::Error.new("Could not read pixels: ")

        # # Each pixel
        # bytes_per_pixel = BIT_DEPTH / 8
        # pixel_count = (window.width) * (window.height)
        # bytesize = (pixel_count * bytes_per_pixel + BMP_HEADER_SIZE).to_i
        # pixels = Bytes.new(bytesize) # 198)

        # wand = LibMagick.newMagickWand
        # rw = LibSDL.rw_from_mem(pixels, pixels.size)
        # LibSDL.save_bmp_rw(surface, rw, 1)
        # LibSDL.free_surface surface

        if true # LibMagick.magickReadImageBlob wand, pixels, pixels.size
          # LibMagick.magickWriteImage wand, "dithered.png"
          # magnify = 2.5
          # puts (window.width * magnify).to_i
          # puts (window.height * magnify).to_i
          # LibMagick.magickMagnifyImage wand
          # LibMagick.magickInterpolativeResizeImage wand, (window.width * magnify).to_i, (window.height * magnify).to_i, LibMagick::PixelInterpolateMethod::AverageInterpolatePixel
          # LibMagick.magickAdaptiveResizeImage wand, (window.width * magnify).to_i, (window.height * magnify).to_i
          # LibMagick.magickSampleImage wand, (window.width * magnify).to_i, (window.height * magnify).to_i
          # LibMagick.magickResizeImage wand, (window.width * magnify).to_i, (window.height * magnify).to_i, LibMagick::FilterType::BoxFilter
          # puts "Rescale"
          # LibMagick.magickLiquidRescaleImage wand, (window.width * magnify).to_i, (window.height * magnify).to_i, 0, 0
          # LibMagick.magickScaleImage wand, (window.width * magnify).to_i, (window.height * magnify).to_i
          # puts "Dither"
          # LibMagick.magickRemapImage wand, @@wand, LibMagick::DitherMethod::FloydSteinbergDitherMethod
          # puts "Done"
          # LibMagick.magickRemapImage wand, @@wand, LibMagick::DitherMethod::NoDitherMethod
          # if LibMagick.magickWriteImage wand, "dithered.png"
          #   puts "Write success"
          # else
          #   puts "Write error"
          # end
        else
          puts "Read image error"
        end
        # LibMagick.magickSetImageFormat wand, "BMP"

        # buffer = LibMagick.magickGetImageBlob wand, out length
        # # # puts "#{buffer.class}, #{length}"
        # p = Bytes.new(buffer, length)
        # LibMagick.magickRelinquishMemory buffer
        # rw = LibSDL.rw_from_mem(p, p.size)
        # if !(surface = LibSDL.load_bmp_rw(rw, 1))
        #   SDL::Error.new("Unable to load image")
        # end

        # if !(surface = SDL.load_bmp("dithered.png"))
        #   SDL::Error.new("Unable to load image")
        # end
        # texture = LibSDL.create_texture_from_surface(renderer, surface)
        start_x = -1500
        start_y = -500

        while true
          sleep 20.milliseconds
          renderer.clear

          start_x += 1
          # start_y -= 1

          # (unused, w, h, bd, rmask, gmask, bmask, amask)
          # surface = LibSDL.create_rgb_surface(0, WIDTH, HEIGHT, BIT_DEPTH, 0xff000000, 0x00ff0000, 0x0000ff00, 0)
          # format = surface.value.format.value

          # rect = Rect.new(0, 0, WIDTH, HEIGHT)
          # renderer.viewport = rect
          # # nil is Rect for what to copy
          # error = LibSDL.render_read_pixels(renderer, pointerof(rect), format.format, surface.value.pixels, surface.value.pitch)
          # renderer.clear

          # error = 0
          # if error != 0
          #   SDL::Error.new("Could not read pixels: ")
          # end

          # # Each pixel

          # wand = LibMagick.newMagickWand
          # rw = LibSDL.rw_from_mem(pixels, pixels.size)
          # LibSDL.save_bmp_rw(surface, rw, 1)
          # LibSDL.free_surface surface

          # if LibMagick.magickReadImageBlob wand, pixels, pixels.size
          #   # LibMagick.magickRemapImage wand, @@wand, LibMagick::DitherMethod::FloydSteinbergDitherMethod
          #   # LibMagick.magickRemapImage wand, @@wand, LibMagick::DitherMethod::NoDitherMethod
          #   LibMagick.magickSetImageFormat wand, "BMP"
          #   # if LibMagick.magickWriteImage wand, "dithered.png"
          #   #   puts "Write success"
          #   # else
          #   #   puts "Write error"
          #   # end
          # else
          #   puts "Read image error"
          # end
          # # renderer.clear
          # LibMagick.magickRelinquishMemory buffer

          # p = pixels
          # LibSDL.free_surface surface

          rect = Rect.new(start_x, start_y, (window.width * 2.5).to_i, (window.height * 2.5).to_i)
          renderer.viewport = rect

          renderer.copy(texture)
          renderer.viewport = player_rect
          renderer.copy(player_texture)

          renderer.present
        end
        LibSDL.destroy_texture texture
        # LibMagick.destroyMagickWand wand # lib deinit
        LibMagick.magickWandTerminus # lib deinit
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
