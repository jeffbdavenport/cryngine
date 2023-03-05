require "./frame"
require "../display/renderer"

module Cryngine
  class Map
    abstract class Grid
      alias Window = Display::Window
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

      getter render_type = Display::Renderer::RenderTypes::Pixels

      getter col_adjust : UInt16
      getter row_adjust : UInt16
      getter sheet_col_adjust : Int16
      getter sheet_row_adjust : Int16
      getter map : Map

      # @sheets : Hash(Int16, Hash(Int16, Sheet)) = {} of Int16 => Hash(Int16, Sheet)

      def initialize(map : Map, width : Int32 = Window.window.width, height : Int32 = Window.window.height, @center_block : Block = Player.block, tile_width : UInt8 = map.tile_width, tile_height : UInt8 = map.tile_height, @view_scale = 1.0, montage = false, centered = true)
        @map = map
        @sheet_frame = Frame.new(width, height, tile_width, tile_height)
        @half_sheet_frame = Frame.new((width / 2.0).to_i16, (height / 2.0).to_i16, tile_width, tile_height)
        if montage
          @x_between_distance = @sheet_frame.cols.to_i16
          @y_between_distance = @sheet_frame.rows.to_i16
        else
          @x_between_distance = (@sheet_frame.cols - (Window.window.width / (map.tile_width * map.scale))).floor.to_i16 - 4_i16
          @y_between_distance = (@sheet_frame.rows - (Window.window.height / (map.tile_height * map.scale))).floor.to_i16 - 4_i16
        end

        if centered
          @col_adjust = half_sheet_frame.cols
          @row_adjust = half_sheet_frame.rows
          @sheet_col_adjust = (x_between_distance / 2.0).to_i16
          @sheet_row_adjust = (y_between_distance / 2.0).to_i16
        else
          @col_adjust = 0_u16
          @row_adjust = 0_u16
          @sheet_col_adjust = 0_i16
          @sheet_row_adjust = 0_i16
        end

        if @x_between_distance == 0 || @y_between_distance == 0
          raise SheetWidthZero.new("Distance between sheets cannot be Zero. X: #{@x_between_distance}, Y: #{y_between_distance}")
        end
      end

      def sheet_for(block : Block)
        {sheet_col(block.real_x), sheet_row(block.real_y)}
      end

      def start_sheet(col : Int16, row : Int16)
        mutex.synchronize do
          block = block_for(col, row)
          raise SheetAlreadyStartedError.new("#{col}, #{row}") if sheet_started?(block)
          raise SheetExistsError.new("#{col}, #{row}") if sheet_exists?(block)
          @started_sheets[block] = true
        end
      end

      def block_for(col : Int16, row : Int16)
        real_x = (offset_x + x_between_distance * col).to_i64
        real_y = (offset_y + y_between_distance * row).to_i64

        Map::Block.from_real real_x, real_y
      end

      def sheet_col(real_x)
        # puts "realx: #{real_x}, offset: #{offset_x}, adjust #{sheet_col_adjust}, between: #{x_between_distance}"
        x = real_x - (offset_x) + sheet_col_adjust
        (x/x_between_distance).floor.to_i16
      end

      def sheet_row(real_y)
        y = real_y - (offset_y) + sheet_row_adjust
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

      def sheet_started?(block : Block) : Bool
        !!@started_sheets[block]?
      end

      def sheet_started?(col, row) : Bool
        !!@started_sheets[block_for(col, row)]?
      end
    end
  end
end
