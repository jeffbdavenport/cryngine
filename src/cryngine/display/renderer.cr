require "./window"

module Cryngine
  module Display
    module Renderer
      include SDL
      alias Window = Display::Window

      WIDTH           = Display::Window::WIDTH
      HEIGHT          = Display::Window::HEIGHT
      BIT_DEPTH       = Display::Window::BIT_DEPTH
      BMP_HEADER_SIZE = 54
      class_getter renderer : SDL::Renderer
      class_getter surface : Pointer(LibSDL::Surface)
      class_getter textures = {} of String => Texture
      class_getter render_channel = Channel(Array(Tuple(Rect, SDL::Texture, Rect | Nil))).new(1)
      # class_getter present_channel = Channel(Nil).new(10000)
      # Makes sheet based of where the center of the screen is (col, row)
      class_getter render_sheets_channel = Channel(Tuple(Int16, Int16, Array(Tuple(String, Rect, Rect)))).new(9)
      class_getter render_sheets_channel_wait = Channel(Nil).new(1)
      class_getter publish_made_sheets_channel = Channel(Tuple(Int16, Int16, Pointer(LibSDL::Surface))).new(9)
      class_getter cleanup_channel = Channel(Tuple(Int16, Int16, Pointer(LibSDL::Texture), Pointer(LibSDL::Surface))).new(1)
      class_getter load_surface_channel = Channel(Tuple(Int16, Int16, Bytes)).new(9)
      class_getter load_surface_wait_channel = Channel(Nil).new(1)
      class_property player_rect : Rect
      class_property player_texture : Texture
      class_getter mutex : Mutex
      class_getter lock_mutex : Mutex
      class_property render_book : TextureBook
      class_property render_lock = false
      class_getter clear_channel = Channel(Nil).new(1)
      class_getter update_channel = Channel(Nil).new(1)
      class_getter next_render_channel = Channel(Nil).new(1)

      @@lock_mutex = Mutex.new
      @@mutex = Mutex.new
      @@render_book = uninitialized TextureBook
      @@player_texture = uninitialized Texture
      @@player_rect = uninitialized Rect
      @@renderer = uninitialized Renderer
      @@surface = uninitialized Pointer(LibSDL::Surface)
      @@start_time : Float64 = Time.monotonic.total_seconds
      @@printed_frame = false

      def self.window
        Display::Window.window
      end

      def self.initialize(game_title, width, height)
        spawn do
          Display::Window.window = SDL::Window.new(game_title, width, height) # , flags: LibSDL::WindowFlags::FULLSCREEN_DESKTOP)
          usleep 100.milliseconds
          Display::Window.window.recalc_window_size
          @@renderer = Renderer.new(window)
          @@surface = new_surface(renderer)
          @@player_rect = Rect.new(((window.width / 2) - 60).to_i, ((window.height / 2) - 71).to_i, 120, 142)
          @@player_texture = load_img_texture "assets/sprites/full/models/male_redone_OC.png"
          Player.initialize(window, 7, -17)
          Sheet.initialize(window, Player.block)

          # Log.debug { "Player: #{Player.col}, #{Player.row}: #{Player.block.real_x}, #{Player.block.real_y}" }

          Map.tilesets.each do |name, tileset|
            textures[name] = load_img_texture tileset.image
          end
          @@render_book = TextureBook.new(view_scale: Map.scale)
          SheetMaker.initialize
          render_sheets_channel_wait.receive

          count = 0
          start_time = Time.monotonic.total_seconds
          Loop.new(:render, same_thread: true) do
            textures = render_channel.receive
            textures.each do |rect, texture, clip_rect|
              renderer.viewport = rect
              if clip_rect
                renderer.copy(texture.to_unsafe, clip_rect)
              else
                renderer.copy(texture.to_unsafe)
              end
            end
            # Window.update_channel.send(nil)
            # end

            # Loop.new(:present, same_thread: true) do
            # present_channel.receive

            mutex.synchronize do
              # time = Time.measure {
              renderer.present
              renderer.clear
              # }
              if render_sheets_channel_wait.waiting?
                render_sheets_channel_wait.send(nil)
              elsif load_surface_wait_channel.waiting?
                load_surface_wait_channel.send(nil)
              end
              Window.update_channel.send(nil)
              # puts time if time > 2.5.milliseconds
              unless @@printed_frame
                @@printed_frame = true
                Log.debug { " - - First Frame time: #{Time.monotonic.total_seconds - @@start_time}" }
              end

              # Log.debug { "Clear render" }
            end
            self.render_lock = false

            count += 1
            time = Time.monotonic.total_seconds
            if (time - start_time) >= 1.0
              puts count
              count = 0
              start_time = time
            end
          end

          Loop.new(:render_sheet_maker, same_thread: true) do
            col, row, printables = render_sheets_channel.receive

            render_sheets_channel_wait.receive

            mutex.synchronize do
              Log.debug { "DO   - RENDERING #{col},#{row}" }
              # renderer.clear
              printables.each do |texture_name, view_rect, clip|
                renderer.viewport = view_rect
                renderer.copy textures[texture_name], clip
              end
              copy_renderer_to_surface(renderer, surface)
              # renderer.clear
            end
            # LibIMG.save_png surface, "rendered#{col},#{row}.png"
            Log.debug { "DONE - RENDERING #{row}, #{col}" }

            render_sheets_channel_wait.receive

            if SheetMaker.dither
              sheet = surface_as_bytes(surface)
              Fiber.yield
              SheetMaker.pixel_book.create_sheet(col, row, sheet)
              Log.debug { "Started sheet in Renderer  #{col}, #{row}" }
              render_book.start_sheet(col, row)
              SheetMaker.made_sheets_channel.send({col, row, sheet})
            else
              sheet = SDL::Texture.new(LibSDL.create_texture_from_surface(renderer, surface))
              render_book.create_sheet(col, row, sheet)
              # Log.debug { "Finished sheet #{col}, #{row}" }
            end
          end

          1.times do
            Loop.new(:load_surface) do
              col, row, bmp_bytes = load_surface_channel.receive
              # unless col == 0 && row == 0
              #   load_surface_wait_channel.receive
              # end
              # mutex.synchronize do
              render_sheets_channel_wait.receive
              rw = LibSDL.rw_from_mem(bmp_bytes, bmp_bytes.size)
              surface = LibSDL.load_bmp_rw(rw, 1)
              Log.debug { "Loaded surface #{col}, #{row}" }
              # LibIMG.save_png surface, "finished#{col},#{row}.png"
              LibMagick.magickRelinquishMemory bmp_bytes

              publish_made_sheets_channel.send({col, row, surface})
            end
          end

          8.times do
            Loop.new(:cleanup) do
              col, row, texture, surface = cleanup_channel.receive
              Log.debug { "created texture #{col}, #{row}" }
              render_sheets_channel_wait.receive
              render_book.create_sheet(col, row, SDL::Texture.new(texture))
              Log.debug { "-- Finished sheet #{col}, #{row}" }

              # # TODO : DELETE
              # LibIMG.save_png surface, "dithered#{col},#{row}.png"

              render_sheets_channel_wait.receive
              LibSDL.free_surface surface
              # GC.collect
              Log.debug { "-- Finished cleanup" }
            end
          end

          Loop.new(:publish_made_sheets, same_thread: true) do
            col, row, surface = publish_made_sheets_channel.receive
            # puts "Publishing #{col}, #{row}"
            render_sheets_channel_wait.receive
            texture = LibSDL.create_texture_from_surface(renderer, surface)
            # sheet = Sheet.new(col, row, texture)
            # if render_book.sheet_exists?(col, row)
            #   sheet = render_book.sheet(col, row)
            #   sheet.clear
            # end
            cleanup_channel.send({col, row, texture, surface})
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
        frame = SheetMaker.pixel_book.sheet_frame
        rect = Rect.new(0, 0, frame.pixels_width.to_i, frame.pixels_height.to_i)
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
