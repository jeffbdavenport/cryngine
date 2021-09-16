require "./block"
require "../map"
require "../display/renderer"

module Cryngine
  module Map
    module Player
      class_getter block : Block
      class_getter col : Float64
      class_getter row : Float64
      class_getter unscaled_col : Float64
      class_getter unscaled_row : Float64
      @@col = uninitialized Float64
      @@row = uninitialized Float64
      @@unscaled_col = uninitialized Float64
      @@unscaled_row = uninitialized Float64
      class_getter player_height : Int32 = 61
      class_getter update_center_channel = Channel(Tuple(Int16, Int16, TextureBook, Block)).new(1)

      class_property updated = false
      @@block = uninitialized Block

      CHECK_BLOCK_BOUNDRY = 5

      def self.initialize(window, real_x : Int64, real_y : Int64)
        @@block = Map::Block.from_real(real_x, real_y)
        width = window.width   # - (Map.tile_width * 2)
        height = window.height # - (Map.tile_height * 2)
        @@col = ((width / (Map.tile_width * Map.scale)).to_i / 2.0)
        @@row = ((height / (Map.tile_height * Map.scale)).to_i / 2.0)
        @@unscaled_col = ((width / Map.tile_width).to_i / 2.0)
        @@unscaled_row = ((height / Map.tile_height).to_i / 2.0)
        # puts "#{@@col},#{@@row}:#{@@unscaled_col},#{@@unscaled_row}"

        spawn do
          Loop.new(:update_center) do
            move_x, move_y, book, prev = update_center_channel.receive
            [0_i16, move_x].each do |x|
              [0_i16, move_y].each do |y|
                next if x == 0 && y == 0
                check_block = prev.move(x * CHECK_BLOCK_BOUNDRY, y * CHECK_BLOCK_BOUNDRY)
                prev_sheet = book.center_block_for(prev)

                sheet = book.center_block_for(check_block)
                col = book.sheet_col(check_block.real_x)
                row = book.sheet_row(check_block.real_y)

                if prev_sheet != sheet && !SheetMaker.pixel_book.sheet_started?(col, row)
                  # Log.debug { "--- Current Player Sheet: #{col},#{row}" }
                  # Log.debug { "--- Player block: #{block.real}" }
                  # Log.debug { "--- New Center block: #{sheet.real}" }
                  # Log.debug { "--- 1,2 is; : #{book.block_for(2, 1).real}" }
                  # Log.debug { "--- 1,1 is; : #{book.block_for(1, 1).real}" }
                  Window.map_checker_channel.send({col, row})
                end
              end
            end
            # Either get the center_block for current position, and update the centor_block to that or:
          end
        end
      end

      def self.move(book : TextureBook, col : Int16, row : Int16)
        # sheet = Sheet.sheet_from(@@block)
        prev = @@block
        self.updated = true
        @@block = block.move col, row

        update_center_channel.send({col, row, book, prev})
        # new_sheet = begin
        #   Sheet.sheet_from(@@block)
        # rescue KeyError
        #   nil
        # end
        # if sheet != new_sheet
        # Display::Window.map_checker_channel.send(nil)
        # end
        @@block
      end

      def self.pixels_col
        (col * Map.tile_width).to_i
      end

      def self.pixels_row
        (row * Map.tile_height).to_i
      end

      def self.pixels_width
        (unscaled_col * 2 * Map.tile_width * Map.scale).to_i
      end

      def self.pixels_height
        (unscaled_row * 2 * Map.tile_width * Map.scale).to_i
      end

      def self.unscaled_pixels_col
        (unscaled_col * Map.tile_width * Map.scale).to_i
      end

      def self.unscaled_pixels_row
        (unscaled_row * Map.tile_height * Map.scale).to_i
      end

      def self.scaled_pixels_col
        (col * Map.tile_width * Map.scale).to_i
      end

      def self.scaled_pixels_row
        (row * Map.tile_height * Map.scale).to_i
      end
    end
  end
end
