require "./block"
require "../map"
require "../display/renderer"

module Cryngine
  module Map
    module Player
      class_getter block : Block
      class_property player_height : Int32 = 0
      class_getter update_center_channel = Channel(Tuple(Int16, Int16, TextureBook, Block)).new(1)
      class_property current_layer = 3

      class_property updated = false
      @@block = uninitialized Block

      CHECK_BLOCK_BOUNDRY = 4

      def self.initialize(real_x : Int64, real_y : Int64)
        @@block = Map::Block.from_real(real_x, real_y)
        # puts "#{@@col},#{@@row}:#{@@unscaled_col},#{@@unscaled_row}"

        spawn do
          Loop.new(:update_center) do
            move_x, move_y, book, block = update_center_channel.receive
            Log.debug { "Player update center" }
            prev_sheet = book.center_block_for(block)

            prev_col = book.sheet_col(block.real_x)
            prev_row = book.sheet_row(block.real_y)

            unless SheetMaker.pixel_book.sheet_started?(prev_col, prev_row)
              Window.map_checker_channel.send({prev_col, prev_row})
            end

            [0_i16, move_x].each do |x|
              [0_i16, move_y].each do |y|
                next if x == 0 && y == 0
                check_block = block.move(x * CHECK_BLOCK_BOUNDRY, y * CHECK_BLOCK_BOUNDRY)

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
        self.updated = true
        @@block = block.move col, row

        # update_center_channel.send({col, row, book, @@block})

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
    end
  end
end
