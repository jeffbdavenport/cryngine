require "./window"

module Cryngine
  module Display
    module Renderer
      include SDL

      WIDTH           = Display::Window::WIDTH
      HEIGHT          = Display::Window::HEIGHT
      BIT_DEPTH       = Display::Window::BIT_DEPTH
      BMP_HEADER_SIZE = 54
      class_getter renderer : SDL::Renderer
      class_getter surface : Pointer(LibSDL::Surface)
      class_getter textures = {} of String => Texture
      class_getter render_channel = Channel(Tuple(Rect, SDL::Texture, Rect | Nil)).new
      class_getter present_channel = Channel(Nil).new(2)
      # Makes sheet based of where the center of the screen is (col, row)
      class_getter sheet_maker_channel = Channel(Tuple(Int16, Int16, Block)).new(9)
      class_getter publish_made_sheets_channel = Channel(Tuple(Int16, Int16, Pointer(LibSDL::Surface))).new(9)
      class_getter load_surface_channel = Channel(Tuple(Int16, Int16, Bytes)).new(9)
      class_property player_rect : Rect
      class_property player_texture : Texture
      class_getter mutex : Mutex
      class_property render_book : TextureBook

      @@mutex = Mutex.new
      @@render_book = uninitialized TextureBook
      @@player_texture = uninitialized Texture
      @@player_rect = uninitialized Rect
      @@renderer = uninitialized Renderer
      @@surface = uninitialized Pointer(LibSDL::Surface)

      def self.window
        Display::Window.window
      end

      def self.initialize(game_title, width, height)
        spawn do
          Display::Window.window = SDL::Window.new(game_title, width, height, flags: LibSDL::WindowFlags::FULLSCREEN_DESKTOP)
          @@renderer = Renderer.new(window)
          @@surface = new_surface(renderer)
          @@player_rect = Rect.new(((window.width / 2) - 60).to_i, ((window.height / 2) - 71).to_i, 120, 142)
          @@player_texture = load_img_texture "assets/sprites/full/models/male_redone_OC.png"
          Player.initialize(window, 7, -17)
          Sheet.initialize(window, Player.block)

          Log.debug { "Player: #{Player.col}, #{Player.row}: #{Player.block.real_x}, #{Player.block.real_y}" }

          Map.tilesets.each do |name, tileset|
            textures[name] = load_img_texture tileset.image
          end
          SheetMaker.initialize
          @@render_book = TextureBook.new(view_scale: Map.scale)

          Loop.new(:render, same_thread: true) do
            rect, texture, clip_rect = render_channel.receive
            mutex.synchronize do
              renderer.viewport = rect
              if clip_rect
                renderer.copy(texture.to_unsafe, clip_rect)
              else
                renderer.copy(texture.to_unsafe)
              end
            end
          end

          Loop.new(:present, same_thread: true) do
            present_channel.receive

            mutex.synchronize do
              renderer.present
              renderer.clear
            end
            sleep 600.milliseconds
            # Map::Player.move(1, 1)
          end

          Loop.new(:render_sheet_maker, same_thread: true) do
            col, row, block = sheet_maker_channel.receive

            # Prevent duplicates

            next if SheetMaker.pixel_book.sheet_exists?(col + 1, row + 1)
            next if render_book.sheet_exists?(col + 1, row + 1)

            sheet = SheetMaker.make_sheet col, row, block
            # # puts "Got bytes #{bytes.size}"
            if sheet.is_a?(SDL::Texture)
              render_book.create_sheet(col + 1, row + 1, sheet)
            else
              SheetMaker.made_sheets_channel.send({col, row, sheet})
            end
          end

          4.times do
            Loop.new(:load_surface) do
              col, row, bmp_bytes = load_surface_channel.receive

              # mutex.synchronize do
              rw = LibSDL.rw_from_mem(bmp_bytes, bmp_bytes.size)
              surface = LibSDL.load_bmp_rw(rw, 1)
              puts "Loaded surface"
              LibMagick.magickRelinquishMemory bmp_bytes

              publish_made_sheets_channel.send({col, row, surface})
            end
          end

          Loop.new(:publish_made_sheets, same_thread: true) do
            col, row, surface = publish_made_sheets_channel.receive
            # puts "Publishing #{col}, #{row}"
            # puts "Loaded surface"
            # sleep 400.milliseconds
            # LibIMG.save_png surface, "dithered#{col},#{row}.png"
            texture = LibSDL.create_texture_from_surface(renderer, surface)
            puts "created texture"
            # sheet = Sheet.new(col, row, texture)
            if render_book.sheet_exists?(col, row)
              sheet = render_book.sheet(col, row)
              sheet.clear
            end
            render_book.create_sheet(col, row, SDL::Texture.new(texture))
            puts "created sheet"
            LibSDL.free_surface surface
            GC.collect
          end

          Display::Window.update_channel.send(nil)
        end
      end

      def self.new_surface(renderer)
        surface = LibSDL.create_rgb_surface(0, window.width, window.height, BIT_DEPTH, 0xff000000, 0x00ff0000, 0x0000ff00, 0)
        texture = LibSDL.create_texture_from_surface(renderer, surface)
        LibSDL.set_render_target renderer, texture
        surface
      end

      def self.copy_renderer_to_surface(renderer, surface)
        rect = Rect.new(0, 0, window.width, window.height)
        renderer.viewport = rect
        renderer.read_pixels(rect, surface)
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
        Texture.new(texture)
      end
    end
  end
end
