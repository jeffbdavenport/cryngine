require "./block"
require "../map"
require "../display/renderer"

module Cryngine
  class Map
    module Player
      class_property block : Block
      class_property player_height : Int32 = 0
      class_getter update_center_channel = Channel(Tuple(Int16, Int16, Block, Block)).new(1)
      class_property updated = false
      @@block = uninitialized Block

      def self.initialize(real_x : Int64, real_y : Int64)
        @@block = Map::Block.from_real(real_x, real_y)
      end

      def self.watch_move(&yield_to : Int16, Int16, Block, Block ->)
        # puts "#{@@col},#{@@row}:#{@@unscaled_col},#{@@unscaled_row}"

        spawn do
          Loop.new(:update_center) do
            move_x, move_y, block, prev_block = update_center_channel.receive

            spawn same_thread: true do
              yield_to.call(move_x, move_y, block, prev_block)
            end
          end
        end
      end

      def self.move(col : Int16, row : Int16)
        # sheet = Sheet.sheet_from(@@block)
        self.updated = true
        prev_block = @@block
        @@block = block.move col, row

        update_center_channel.send({col, row, @@block, prev_block})

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
