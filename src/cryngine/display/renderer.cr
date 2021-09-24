require "./window"

module Cryngine
  module Display
    module Renderer
      include SDL
      # If this is not here Window refers to SDL::Window
      alias Window = Display::Window

      BIT_DEPTH       = 24
      BMP_HEADER_SIZE = 54
      class_getter renderer : SDL::Renderer
      class_getter surface : Pointer(LibSDL::Surface)
      class_getter render_channel = Channel(Array(Tuple(Rect, SDL::Texture, Rect?))).new(1)
      class_getter render_sheets_channel = Channel(Tuple(RenderTypes, Channel(TextureType), Array(Tuple(SDL::Texture, Rect, Rect)))).new(9)
      class_getter publish_made_sheets_channel = Channel(Tuple(Channel(SDL::Texture), Pointer(LibSDL::Surface))).new(9)
      class_getter cleanup_channel = Channel(Pointer(LibSDL::Surface)).new(1)
      class_getter load_surface_channel = Channel(Tuple(Channel(SDL::Texture), Pixels)).new(9)
      class_getter render_print_wait = Channel(Nil).new(1)
      @@load_texture_channel = Channel(Tuple(Channel(SDL::Texture), String)).new(1)
      class_getter mutex : Mutex
      class_getter clear_channel = Channel(Nil).new(1)

      @@mutex = Mutex.new
      @@renderer = uninitialized Renderer
      @@surface = uninitialized Pointer(LibSDL::Surface)
      @@start_time : Float64 = Time.monotonic.total_seconds
      @@printed_frame = false
      @@initialized = false

      alias TextureType = SDL::Texture | Pixels
      enum RenderTypes
        Texture
        Pixels
      end

      private def self.window
        Display::Window.window
      end

      def self.load_texture(path : String) : SDL::Texture
        receive = Channel(SDL::Texture).new(1)
        @@load_texture_channel.send({receive, path})
        receive.receive
      end

      def self.initialize(game_title : String, width = WIDTH, height = HEIGHT, flags : SDL::Window::Flags = SDL::Window::Flags::SHOWN)
        return if @@initialized
        @@initialized = true
        spawn do
          Display::Window.window = SDL::Window.new(game_title, width, height, flags: flags)
          sleep 100.milliseconds
          window.recalc_window_size
          @@renderer = Renderer.new(window)
          @@surface = new_surface(renderer)

          Loop.new(:load_textures, same_thread: true) do
            reply_to, img_path = @@load_texture_channel.receive
            texture = load_img_texture img_path
            reply_to.send(texture)
          end

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

            mutex.synchronize do
              # time = Time.measure {
              if textures.any?
                renderer.present
                renderer.clear
              end
              # }
              if render_print_wait.waiting?
                render_print_wait.send(nil)
              end
              Window.update_channel.send(nil)
              # puts time if time > 2.5.milliseconds
              unless @@printed_frame
                @@printed_frame = true
                Log.debug { " - - First Frame time: #{Time.monotonic.total_seconds - @@start_time}" }
              end

              # Log.debug { "Clear render" }
            end

            count += 1
            time = Time.monotonic.total_seconds
            if (time - start_time) >= 1.0
              puts count
              count = 0
              start_time = time
            end
          end

          Loop.new(:render_sheet, same_thread: true) do
            render_type, reply_to, printables = render_sheets_channel.receive

            render_print_wait.receive

            mutex.synchronize do
              Log.debug { "DO   - RENDERING Above" }

              LibSDL.set_render_draw_color(renderer, 255, 255, 255, 0)
              renderer.clear

              printables.each do |texture, view_rect, clip|
                renderer.viewport = view_rect
                renderer.copy texture, clip
              end
              copy_renderer_to_surface(renderer, surface)
              renderer.clear
            end
            # LibIMG.save_png surface, "rendered#{col},#{row}.png"
            Log.debug { "DONE - RENDERING Above" }

            render_print_wait.receive

            sheet = case render_type
                    when RenderTypes::Pixels
                      surface_as_pixels(surface)
                    when RenderTypes::Texture
                      SDL::Texture.new(LibSDL.create_texture_from_surface(renderer, surface))
                    end
            raise RenderInvalidType.new("Unknown type #{render_type}") if sheet.nil?
            reply_to.send(sheet)
          end

          2.times do
            Loop.new(:load_surface) do
              reply_to, bmp_bytes = load_surface_channel.receive
              render_print_wait.receive
              rw = LibSDL.rw_from_mem(bmp_bytes, bmp_bytes.size)
              surface = LibSDL.load_bmp_rw(rw, 1)
              Log.debug { "Loaded surface" }
              # LibIMG.save_png surface, "finished#{col},#{row}.png"
              LibMagick.magickRelinquishMemory bmp_bytes

              publish_made_sheets_channel.send({reply_to, surface})
            end
          end

          Loop.new(:cleanup) do
            surface = cleanup_channel.receive

            LibSDL.free_surface surface
          end

          Loop.new(:publish_made_sheets, same_thread: true) do
            reply_to, surface = publish_made_sheets_channel.receive
            Log.debug { "Publishing Texture" }
            render_print_wait.receive

            LibSDL.set_color_key(surface, 1, LibSDL.map_rgb(surface.value.format, 255, 255, 255))
            texture = LibSDL.create_texture_from_surface(renderer, surface)
            cleanup_channel.send(surface)
            texture = SDL::Texture.new(texture)
            reply_to.send(texture)
          end

          # Display::Window.update_channel.send(nil)
        end
      end

      private def self.new_surface(renderer)
        surface = LibSDL.create_rgb_surface(0, window.width, window.height, BIT_DEPTH, 0xff000000, 0x00ff0000, 0x0000ff00, 0)
        texture = LibSDL.create_texture_from_surface(renderer, surface)
        LibSDL.set_render_target renderer, texture
        surface
      end

      private def self.copy_renderer_to_surface(renderer, surface)
        rect = Rect.new(0, 0, window.width.to_i, window.height.to_i)
        renderer.viewport = rect
        renderer.read_pixels(rect, surface)
      end

      private def self.surface_as_pixels(surface)
        bytes_per_pixel = BIT_DEPTH / 8
        pixel_count = (window.width) * (window.height)
        bytesize = (pixel_count * bytes_per_pixel + BMP_HEADER_SIZE).to_i
        pixels = Pixels.new(bytesize) # 198)

        rw = LibSDL.rw_from_mem(pixels, pixels.size)
        LibSDL.save_bmp_rw(surface, rw, 1)
        pixels
      end

      private def self.load_img_texture(path : String)
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