require "../map/book"
require "../map/book/sheet"
require "../map/texture_book"
require "../map/pixel_book"

module Cryngine
  module Display
    module SheetMaker
      class_getter dither_channel = Channel(Nil).new(1)

      @@mutex = Mutex.new
      class_getter mutex : Mutex

      class_getter dither = false
      class_property montage_map = false
      class_property max_layer = 3
      class_getter made_sheets_channel = Channel(Tuple(Int16, Int16, Bytes, Bool)).new(9)
      class_getter sheet_maker_channel = Channel(Tuple(Int16, Int16, Block)).new(9)

      class_getter map_size = 0

      @@sheets = {} of Int16 => Array(Int16)

      class_getter pixel_book_below : PixelBook
      @@pixel_book_below = uninitialized PixelBook
      class_getter pixel_book_above : PixelBook
      @@pixel_book_above = uninitialized PixelBook

      def self.dither(dither_colors_image)
        raise "Already set Dither" if @@dither
        @@dither = true
        DitherTool.dither_colors_image = dither_colors_image
        nil
      end

      def self.pixel_book
        @@pixel_book_below
      end

      def self.initialize
        spawn do
          # There should never be more than 5 new sheets to make in one frame after the first
          @@pixel_book_below = PixelBook.new(montage: montage_map)
          @@pixel_book_above = PixelBook.new(montage: montage_map)

          if @@dither
            min_x = (Map.layers.values.map(&.startx).min)
            min_y = (Map.layers.values.map(&.starty).min)

            start_col = pixel_book.sheet_col min_x
            start_row = pixel_book.sheet_col min_y
            puts Map.layers.values.map { |value| value.chunks.map(&.x) }
            max_x = (Map.layers.values.map { |value| value.chunks.map(&.x).max * Chunk.width }.max + Chunk.width)
            max_y = (Map.layers.values.map { |value| value.chunks.map(&.y).max * Chunk.height }.max + Chunk.height)
            end_col = pixel_book.sheet_col max_x
            end_row = pixel_book.sheet_row max_y
            puts "Max xy: #{max_x}:#{max_y}"

            width_mult = (end_col - start_col).abs + 1
            height_mult = (end_row - start_row).abs + 1
            # puts "#{start_col}:#{end_col} - #{start_row}:#{end_row}"

            @@map_size = (width_mult * height_mult).to_i

            # puts "#{@@map_size} wh: #{width_mult},#{height_mult}"

            if montage_map
              Renderer.render_book_above = TextureBook.new(width: (pixel_book.sheet_frame.pixels_width * Map.scale).to_i * width_mult, height: (pixel_book.sheet_frame.pixels_height * Map.scale).to_i * height_mult, tile_width: (Map.tile_width * Map.scale).to_i, tile_height: (Map.tile_height * Map.scale).to_i, montage: montage_map)
              Renderer.render_book_below = TextureBook.new(width: (pixel_book.sheet_frame.pixels_width * Map.scale).to_i * width_mult, height: (pixel_book.sheet_frame.pixels_height * Map.scale).to_i * height_mult, tile_width: (Map.tile_width * Map.scale).to_i, tile_height: (Map.tile_height * Map.scale).to_i, montage: montage_map)
            else
              Renderer.render_book_below = TextureBook.new(width: (pixel_book.sheet_frame.pixels_width * Map.scale).to_i, height: (pixel_book.sheet_frame.pixels_height * Map.scale).to_i, tile_width: (Map.tile_width * Map.scale).to_i, tile_height: (Map.tile_height * Map.scale).to_i)
              Renderer.render_book_above = TextureBook.new(width: (pixel_book.sheet_frame.pixels_width * Map.scale).to_i, height: (pixel_book.sheet_frame.pixels_height * Map.scale).to_i, tile_width: (Map.tile_width * Map.scale).to_i, tile_height: (Map.tile_height * Map.scale).to_i)
            end
          end

          8.times do
            Loop.new(:sheet_maker_receiver, same_thread: true) do
              col, row, block = sheet_maker_channel.receive
              Log.debug { "Making sheet channel" }

              mutex.synchronize do
                next if pixel_book.sheet_exists?(col, row)
                next if Renderer.render_book.sheet_exists?(col, row)
              end

              Log.debug { "Making sheet #{col}, #{row}" }
              Renderer.render_sheets_channel_wait.receive
              printables = make_sheet col, row, block
              Renderer.render_sheets_channel.send({col, row, printables, false})

              printables = make_sheet col, row, block, above: true
              Renderer.render_sheets_channel.send({col, row, printables, true})
            end
          end

          2.times do |i|
            Loop.new("made_sheets_receiver_#{i}") do
              col, row, unformatted_sheet, above = made_sheets_channel.receive
              Log.debug { "To make sheet #{col}, #{row}" }

              book = if above
                       SheetMaker.pixel_book_above
                     else
                       SheetMaker.pixel_book_below
                     end
              frame = mutex.synchronize do
                pixel_book.sheet_frame.dup
              end

              if montage_map
                if book.size == map_size
                  render_book = if above
                                  Renderer.render_book_above
                                else
                                  Renderer.render_book_below
                                end
                  next if mutex.synchronize do
                            render_book.sheet_started?(0, 0)
                          end

                  render_book.start_sheet(0, 0)

                  # Renderer.render_sheets_channel_wait.receive
                  bmp_bytes = montage_book(book, above)
                  col = 0_i16
                  row = 0_i16
                else
                  next
                end
              else
                Renderer.render_sheets_channel_wait.receive
                bmp_bytes = dither_sheet(frame, unformatted_sheet, above)
              end

              Fiber.yield
              if bmp_bytes
                # puts "Got BMP #{bmp_bytes.size}"
                Renderer.load_surface_channel.send({col, row, bmp_bytes, above})
              end
            end
          end
          Renderer.render_sheets_channel_wait.send(nil)
        end
      end

      def self.make_sheet(col : Int16, row : Int16, center_block : Block, above = false) : Array(Tuple(String, Rect, Rect))
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
        # Adjsut the camera so the player is in the center
        col_adjust, row_adjust = if montage_map
                                   {0, 0}
                                 else
                                   {half_frame.cols, half_frame.rows}
                                 end

        layer_keys = mutex.synchronize do
          Map.layers.keys
        end.sort

        screen_cols = frame.cols - 1
        screen_rows = frame.rows - 1

        printables = [] of Tuple(String, Rect, Rect)

        Log.debug { "Screen: #{col},#{row} #{screen_cols}, #{screen_rows}" }

        0.upto(screen_rows).each do |row|
          real_y = center_block.real_y + (row - row_adjust)

          0.upto(screen_cols).each do |col|
            real_x = center_block.real_x + (col - col_adjust)
            block = Map::Block.from_real(real_x, real_y)

            layer_keys.each do |id|
              next if id == CollisionMap.layer
              if above
                next if id < Player.current_layer
              else
                next if id >= Player.current_layer
              end

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

      def self.dither_sheet(frame, bytes : Bytes, above) : Bytes?
        result_tool = DitherTool.new
        # Log.debug { "Loading Sheet to Dither" }
        result_tool.load_image(bytes)
        # Fiber.yield
        Log.debug { "Cropping Sheet" }
        LibMagick.magickCropImage(result_tool.wand, frame.pixels_width, frame.pixels_height, 0, 0)
        Fiber.yield
        result_tool.scale(Map.scale, frame.pixels_width.to_i, frame.pixels_height.to_i)
        Log.debug { "Scaled Sheet" }
        Fiber.yield
        result_tool.floyd_steinberg
        Log.debug { "Dithered Sheet" }
        # result_tool.save("non-dithered-draft-#{above}.bmp")
        bytes = result_tool.as_bytes
        # IMPORTANT! Clears GBs of memory
        result_tool.cleanup

        bytes
      end

      def self.montage_book(book : PixelBook, above : Bool, full = true) : Bytes?
        # mutex.synchronize do
        result_tool = DitherTool.new

        if full
          min_x = (Map.layers.values.map(&.startx).min)
          min_y = (Map.layers.values.map(&.starty).min)

          start_col = pixel_book.sheet_col min_x
          start_row = pixel_book.sheet_col min_y
          max_x = (Map.layers.values.map { |value| value.chunks.map(&.x).max * Chunk.width }.max + Chunk.width)
          max_y = (Map.layers.values.map { |value| value.chunks.map(&.y).max * Chunk.height }.max + Chunk.height)
          end_col = pixel_book.sheet_col max_x
          end_row = pixel_book.sheet_row max_y

          width_mult = (end_col - start_col).abs + 1
          height_mult = (end_row - start_row).abs + 1
          # puts "#{above}: #{start_col}:#{end_col}, #{start_row}:#{end_row}, w,h:#{width_mult},#{height_mult}"

          start_row.upto(end_row) do |row|
            start_col.upto(end_col) do |col|
              Log.debug { "Above: #{above} Loading sheet: #{col}, #{row}" }
              sheet = book.sheet(col, row)
              # col , row= book.sheet_for(sheet)
              # sheet = book.sheet(col, row)
              result_tool.load_image(sheet.sheet)
              # wand, width, height, x, y
              LibMagick.magickCropImage(result_tool.wand, book.sheet_frame.pixels_width, book.sheet_frame.pixels_height, 0, 0)
              # result_tool.save("non-dithered-#{above}-#{col}.#{row}.bmp")
            end
          end
          # book.clear
          draw = LibMagick.acquireDrawingWand(nil, nil)

          wand = LibMagick.magickMontageImage result_tool.wand, draw, "#{width_mult}x#{height_mult}", nil, LibMagick::MontageMode::ConcatenateMode, nil
          LibMagick.destroyDrawingWand draw
          result_tool.cleanup
          Log.debug { "Created Montage" }
          result_tool = DitherTool.new(wand)
          Fiber.yield
          width = Renderer.render_book.sheet_frame.pixels_width.to_i
          height = Renderer.render_book.sheet_frame.pixels_height.to_i
          puts "height #{height}"
          result_tool.scale(1.0, width, height)
          # puts wand.value
          # LibMagick.magickResizeImage result_tool.wand, (width * scale).to_i, (height * scale).to_i, LibMagick::FilterType::BoxFilter
        else
          sheet = book.sheet(1, 1)
          result_tool.load_image(sheet.sheet)
          # result_tool.save("non-dithered-draft.bmp")
          LibMagick.magickCropImage(result_tool.wand, book.sheet_frame.pixels_width, book.sheet_frame.pixels_height, 0, 0)
          Fiber.yield
          # result_tool.scale(Map.scale, book.sheet_frame.pixels_width.to_i, book.sheet_frame.pixels_height.to_i)
        end

        Log.debug { "Scaled Montage" }
        Fiber.yield
        result_tool.floyd_steinberg
        Log.debug { "Dithered Montage" }
        # result_tool.save("dithered-draft-#{above}.bmp")

        unless full
          width = book.sheet_frame.pixels_width.to_i * Map.scale
          height = book.sheet_frame.pixels_height.to_i * Map.scale
          # result_tool.save("dithered-draft-#{above}.bmp")
          LibMagick.magickExtentImage(result_tool.wand, width * 3, height * 3, -width, -height)
        end
        Fiber.yield

        # mutex.synchronize do
        bytes = result_tool.as_bytes
        # IMPORTANT! Clears GBs of memory
        result_tool.cleanup

        bytes
        # end
      end

      def self.cleanup
        if @@dither
          DitherTool.cleanup
        end
      end
    end
  end
end
