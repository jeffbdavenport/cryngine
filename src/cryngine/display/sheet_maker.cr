require "../map/book"

module Cryngine
  module Display
    module SheetMaker
      alias Block = Map::Block
      alias Player = Map::Player
      alias Sheet = Map::Sheet
      alias Rect = SDL::Rect
      alias TextureBook = Map::TextureBook

      class_getter dither_channel = Channel(Nil).new(1)

      @@mutex = Mutex.new
      class_getter mutex : Mutex

      @@mutex2 = Mutex.new
      class_getter mutex2 : Mutex

      class_getter dither = false
      class_getter made_sheets_channel = Channel(Tuple(Int16, Int16, Bytes)).new(9)
      class_getter sheet_maker_channel = Channel(Tuple(Int16, Int16, Block)).new(9)
      class_getter update_center_channel = Channel(Block).new(1)

      @@sheets = {} of Int16 => Array(Int16)

      class_getter pixel_book : PixelBook
      @@pixel_book = uninitialized PixelBook

      def self.dither(dither_colors_image)
        raise "Already set Dither" if @@dither
        @@dither = true
        DitherTool.dither_colors_image = dither_colors_image
        nil
      end

      @@make_sheet_mutexes : Array(Mutex) = [Mutex.new, Mutex.new, Mutex.new, Mutex.new]

      def self.initialize
        spawn do
          # There should never be more than 5 new sheets to make in one frame after the first
          @@pixel_book = PixelBook.new(rows: 3.to_i16)
          if @@dither
            Renderer.render_book = TextureBook.new(3.to_i16, 3.to_i16, width: (pixel_book.sheet_frame.pixels_width * Map.scale).to_i, height: (pixel_book.sheet_frame.pixels_height * Map.scale).to_i, tile_width: (Map.tile_width * Map.scale).to_i, tile_height: (Map.tile_height * Map.scale).to_i)
          end

          Loop.new(:update_center) do
            block = update_center_channel.receive
            if Renderer.render_book.outside_center?(block)
              # render_book.center_block = block
              # map_checker_channel.send(nil)
            end
          end

          sheet_maker_mutex = Mutex.new

          Loop.new(:sheet_maker_receiver) do
            col, row, block = sheet_maker_channel.receive

            mutex.synchronize do
              next if pixel_book.sheet_exists?(col, row)
              next if Renderer.render_book.sheet_exists?(col, row)
            end

            mutex.synchronize do
              book = if @@dither
                       pixel_book
                     else
                       Renderer.render_book
                     end

              book.start_sheet(col, row)
            end
            Log.debug { "Making sheet #{col}, #{row}" }
            printables = make_sheet col, row, block

            sheet_maker_mutex.synchronize do
              Renderer.render_sheets_channel.send({col, row, printables})
            end
          end

          8.times do |i|
            Loop.new("made_sheets_receiver_#{i}") do
              col, row, unformatted_sheet = made_sheets_channel.receive
              # puts "To make sheet #{col}, #{row}"

              frame = mutex.synchronize do
                pixel_book.sheet_frame.dup
              end

              bmp_bytes = dither_sheet(frame, unformatted_sheet)

              Fiber.yield
              if bmp_bytes
                # puts "Got BMP #{bmp_bytes.size}"
                Renderer.load_surface_channel.send({col, row, bmp_bytes})
              end
            end
          end
        end
      end

      def self.make_sheet(col : Int16, row : Int16, center_block : Block) : Array(Tuple(String, Rect, Rect))
        # surface = LibSDL.create_rgb_surface(0, Window::WIDTH, Window::HEIGHT, Window::BIT_DEPTH, 0xff000000, 0x00ff0000, 0x0000ff00, 0)
        # window = SDL::Window.new("Sheet Maker", Window::WIDTH, Window::HEIGHT)
        # surface = Window.new_surface_as_render(renderer)
        # renderer = LibSDL.create_software_renderer surface

        book = if @@dither
                 pixel_book
               else
                 Renderer.render_book
               end
        frame = mutex.synchronize do
          book.sheet_frame.dup
        end
        half_frame = mutex.synchronize do
          book.half_sheet_frame.dup
        end

        layer_keys = @@make_sheet_mutexes[0].synchronize do
          Map.layers.keys
        end.sort

        screen_cols = frame.cols - 1
        screen_rows = frame.rows - 1

        printables = [] of Tuple(String, Rect, Rect)

        Log.debug { "Screen: #{col},#{row} #{screen_cols}, #{screen_rows}" }

        0.upto(screen_rows).each do |row|
          real_y = center_block.real_y + (row - half_frame.rows)

          0.upto(screen_cols).each do |col|
            real_x = center_block.real_x + (col - half_frame.cols)
            block = Map::Block.from_real(real_x, real_y)

            layer_keys.each do |id|
              layer = Map.layers[id]
              layer.chunks.each do |chunk|
                next unless chunk.x == block.x && chunk.y == block.y && chunk.data[block.col]?

                rows = chunk.data[block.col]
                next unless rows[block.row]?
                sprite = rows[block.row]
                tile = Map::Tile.new(block.col, block.row, sprite, chunk)
                rect = SDL::Rect.new((col * Map.tile_width).to_i, (row * Map.tile_height).to_i, Map.tile_width, Map.tile_height)

                printables.push({tile.tileset.name, rect, tile.clip})
              end
            end
          end
        end
        Log.debug { "Generated Sheet #{col}, #{row}" }

        printables
      end

      def self.dither_sheet(frame, bytes : Bytes) : Bytes?
        result_tool = DitherTool.new
        Log.debug { "Loading Sheet to Dither" }
        result_tool.load_image(bytes)
        # result_tool.save("non-dithered-draft.bmp")
        # Fiber.yield
        # # Log.debug { "Cropping Sheet" }
        # LibMagick.magickCropImage(result_tool.wand, frame.pixels_width, frame.pixels_height, 0, 0)
        Fiber.yield
        result_tool.scale(Map.scale, frame.pixels_width.to_i, frame.pixels_height.to_i)
        Log.debug { "Scaled Sheet" }
        Fiber.yield
        result_tool.floyd_steinberg
        Log.debug { "Dithered Sheet" }
        bytes = result_tool.as_bytes
        # IMPORTANT! Clears GBs of memory
        result_tool.cleanup

        bytes
      end

      def self.montage_book(book : PixelBook, full = false) : Bytes?
        result_tool = DitherTool.new

        if full
          book.rows.times do |row|
            book.cols.times do |col|
              sheet = book.sheet(col, row)
              result_tool.load_image(sheet.sheet)
              # wand, width, height, x, y
              LibMagick.magickCropImage(result_tool.wand, book.sheet_frame.pixels_width, book.sheet_frame.pixels_height, 0, 0)
              # result_tool.save("non-dithered-#{col}.#{row}.bmp")
            end
          end
          book.clear
          draw = LibMagick.acquireDrawingWand(nil, nil)

          wand = LibMagick.magickMontageImage result_tool.wand, draw, "3x3+0+0", nil, LibMagick::MontageMode::ConcatenateMode, nil
          LibMagick.destroyDrawingWand draw
          result_tool.cleanup
          Log.debug { "Created Montage" }
          result_tool = DitherTool.new(wand)
          Fiber.yield
          result_tool.scale(Map.scale, book.book_frame.pixels_width.to_i, book.book_frame.pixels_height.to_i)
        else
          sheet = book.sheet(1, 1)
          result_tool.load_image(sheet.sheet)
          # result_tool.save("non-dithered-draft.bmp")
          LibMagick.magickCropImage(result_tool.wand, book.sheet_frame.pixels_width, book.sheet_frame.pixels_height, 0, 0)
          Fiber.yield
          result_tool.scale(Map.scale, book.sheet_frame.pixels_width.to_i, book.sheet_frame.pixels_height.to_i)
        end

        Log.debug { "Scaled Montage" }
        Fiber.yield
        result_tool.floyd_steinberg
        Log.debug { "Dithered Montage" }

        unless full
          width = book.sheet_frame.pixels_width.to_i * Map.scale
          height = book.sheet_frame.pixels_height.to_i * Map.scale
          # result_tool.save("dithered-draft.bmp")
          LibMagick.magickExtentImage(result_tool.wand, width * 3, height * 3, -width, -height)
        end
        Fiber.yield

        # mutex.synchronize do
        bytes = result_tool.as_bytes
        # IMPORTANT! Clears GBs of memory
        result_tool.cleanup

        bytes
      end

      def self.cleanup
        if @@dither
          DitherTool.cleanup
        end
      end
    end
  end
end
