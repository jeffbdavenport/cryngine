require "./frame"

module Cryngine
  module Map
    abstract class Book
      getter mutex = Mutex.new

      include Exceptions

      property view_scale : Float64

      getter sheet_frame : Frame
      getter half_sheet_frame : Frame

      getter sheets
      getter center_block : Block
      getter started_sheets : Hash(Block, Bool) = {} of Block => Bool

      getter x_between_distance : Int16
      getter y_between_distance : Int16

      # @sheets : Hash(Int16, Hash(Int16, Sheet)) = {} of Int16 => Hash(Int16, Sheet)

      def initialize(width : Int32 = Window.window.width, height : Int32 = Window.window.height, @center_block : Block = Player.block, tile_width = Map.tile_width, tile_height = Map.tile_height, @view_scale = 1.0)
        @sheet_frame = Frame.new(width.to_i16, height.to_i16, tile_width.to_i16, tile_height.to_i16)
        @half_sheet_frame = Frame.new((width / 2.0).to_i16, (height / 2.0).to_i16, tile_width.to_i16, tile_height.to_i16)
        @x_between_distance = (@sheet_frame.cols - (Window.window.width / (Map.tile_width * Map.scale))).floor.to_i16 - 2
        @y_between_distance = (@sheet_frame.rows - (Window.window.height / (Map.tile_height * Map.scale))).floor.to_i16 - 2

        if @x_between_distance == 0 || @y_between_distance == 0
          raise SheetWidthZero.new("Distance between sheets cannot be Zero. X: #{@x_between_distance}, Y: #{y_between_distance}")
        end
      end

      def start_sheet(col : Int16, row : Int16)
        mutex.synchronize do
          block = block_for(col, row)
          raise SheetAlreadyStartedError.new("#{col}, #{row}") if sheet_started?(block)
          raise SheetExistsError.new("#{col}, #{row}") if sheet_exists?(block)
          @started_sheets[block] = true
        end
      end

      def block_for(col, row)
        real_x = (offset_x + x_between_distance * col).to_i64
        real_y = (offset_y + y_between_distance * row).to_i64

        Map::Block.from_real real_x, real_y
      end

      def sheet_col(real_x)
        x = real_x - (offset_x) + (x_between_distance / 2.0)
        (x/x_between_distance).floor.to_i16
      end

      def sheet_row(real_y)
        y = real_y - (offset_y + 1) + (y_between_distance / 2.0)
        (y/y_between_distance).floor.to_i16
      end

      def center_block_for(block : Block)
        col = sheet_col(block.real_x)
        row = sheet_row(block.real_y)
        block_for(col, row)
      end

      def offset_x
        center_block.real_x
      end

      def offset_y
        center_block.real_y
      end

      def started
        @started_sheets.size
      end

      def started?
        @started_sheets.size > 0
      end

      def empty?
        @started_sheets.size == 0
      end

      def sheet_started?(block : Block)
        @started_sheets[block]?
      end

      def sheet_started?(col, row)
        @started_sheets[block_for(col, row)]?
      end
    end
  end
end
