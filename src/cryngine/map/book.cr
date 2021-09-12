require "./frame"

module Cryngine
  module Map
    abstract class Book
      include Exceptions

      abstract struct Sheet
        getter book

        def self.coord_from_offset(real_xy, center_block_coord, tile_wh)
          coord = real_xy * tile_wh
          offset = center_block_coord * tile_wh
          coord - offset
        end

        def self.window_edge(sheet_pixels_wh, windw_wh)
          (sheet_pixels_wh / 2.0) - (windw_wh / 2.0)
        end

        def self.sheet_offset(col_row, mid_col_row, sheet_pixels_wh)
          (col_row - mid_col_row) * sheet_pixels_wh
        end

        def self.print_wh(x_y, pixels_wh, window_wh)
          pixels_wh = pixels_wh.to_i64
          window_wh = window_wh.to_i64
          # puts "#{x_y}, #{pixels_wh}, #{window_wh}"

          if x_y.positive?
            if (pixels_wh - x_y) > window_wh
              width_height = window_wh
            else
              width_height = pixels_wh - x_y
            end
          else
            width_height = window_wh - x_y.abs
          end
          width_height = 0 if width_height < 0
          width_height
        end

        def x_from_offset(real_x, tile_width)
          self.class.coord_from_offset(real_x, book.offset_x, tile_width)
        end

        def y_from_offset(real_y, tile_height)
          self.class.coord_from_offset(real_y, book.offset_y, tile_height)
        end

        def sheet_x_offset(sheet_pixels_width)
          self.class.sheet_offset(@col, book.mid_col, sheet_pixels_width)
        end

        def sheet_y_offset(sheet_pixels_height)
          self.class.sheet_offset(@row, book.mid_row, sheet_pixels_height)
        end

        def window_left_edge(pixels_width, tile_width, width = Window.window.width)
          self.class.window_edge(pixels_width, width) + (tile_width / 2.0)
        end

        def window_top_edge(pixels_height, height = Window.window.height)
          self.class.window_edge(pixels_height, height)
        end

        def print_width(x, pixels_width, window_width = Window.window.width)
          # puts "#{x}, #{pixels_width}, #{window_width}"
          self.class.print_wh(x, pixels_width, window_width)
        end

        def print_height(y, pixels_height, window_height = Window.window.height)
          self.class.print_wh(y, pixels_height, window_height)
        end

        def clip_rect_x(real_x)
          left_edge = window_left_edge(book.sheet_frame.pixels_width, book.sheet_frame.tile_width, (Window.window.width / view_scale))
          x_offset = x_from_offset(real_x, book.sheet_frame.tile_width)
          sheet_x_offset = sheet_x_offset(book.sheet_frame.pixels_width)

          # puts "L: #{left_edge}, #{sheet_x_offset}, #{x_offset}"
          (left_edge - sheet_x_offset + x_offset).to_i
        end

        def clip_rect_y(real_y)
          top_edge = window_top_edge(book.sheet_frame.pixels_height, (Window.window.height / view_scale))
          y_offset = y_from_offset(real_y, book.sheet_frame.tile_height)
          sheet_y_offset = sheet_y_offset(book.sheet_frame.pixels_height)

          # puts "T: #{left_edge}, #{sheet_x_offset}, #{x_offset}"
          (top_edge - sheet_y_offset + y_offset - (Player.player_height / view_scale)).to_i
        end

        def clip_rect_width(clip_rect_x)
          print_width(clip_rect_x, book.sheet_frame.pixels_width, (Window.window.width / view_scale)).to_i
        end

        def clip_rect_height(clip_rect_y)
          print_height(clip_rect_y, book.sheet_frame.pixels_height, (Window.window.height / view_scale)).to_i
        end

        def view_scale
          book.view_scale
        end

        def rects_from(block : Block) : Tuple(Rect, Rect)
          rect_x = clip_rect_x(block.real_x)
          rect_y = clip_rect_y(block.real_y)

          clip_width = clip_rect_width(rect_x)
          clip_height = clip_rect_height(rect_y)

          view_x = (-rect_x * view_scale).to_i
          view_y = (-rect_y * view_scale).to_i

          rect_x = 0 if rect_x < 0
          rect_y = 0 if rect_y < 0
          clip = Rect.new(rect_x, rect_y, clip_width, clip_height)

          view_x = 0 if view_x < 0
          view_y = 0 if view_y < 0

          view_width = (clip_width * view_scale).to_i
          view_height = (clip_height * view_scale).to_i

          # puts "Col,row #{@col},#{@row} View : #{rect_x}, #{rect_y}: W,H: #{view_width}, #{view_height}"

          view = Rect.new(view_x, view_y, view_width, view_height)
          {view, clip}
          # Rect.new(0, 0, 1680, 880)
        end
      end

      getter cols : Int16
      getter rows : Int16
      getter view_scale : Float64

      getter sheet_frame : Frame
      getter half_sheet_frame : Frame

      getter book_frame : Frame
      getter half_book_frame : Frame

      getter center_block : Block
      @started_sheets : Hash(Int16, Array(Int16)) = {} of Int16 => Array(Int16)

      # @sheets : Hash(Int16, Hash(Int16, Sheet)) = {} of Int16 => Hash(Int16, Sheet)

      def mid_col
        (0..(@cols - 1)).to_a[((@cols - 1) / 2).ceil.to_i]
      end

      def mid_row
        (0..(@rows - 1)).to_a[((@rows - 1) / 2).ceil.to_i]
      end

      def initialize(@cols = 3.to_i16, @rows = 3.to_i16, width : Int32 = Window.window.width, height : Int32 = Window.window.height, @center_block : Block = Player.block, tile_width = Map.tile_width, tile_height = Map.tile_height, @view_scale = 1.0)
        @sheet_frame = Frame.new(width.to_i16, height.to_i16, tile_width.to_i16, tile_height.to_i16)
        @half_sheet_frame = Frame.new((width / 2.0).to_i16, (height / 2.0).to_i16, tile_width.to_i16, tile_height.to_i16)
        @book_frame = Frame.new((@cols * sheet_frame.pixels_width).to_i16, (@rows * sheet_frame.pixels_height).to_i16, tile_width.to_i16, tile_height.to_i16)
        @half_book_frame = Frame.new(((@cols * sheet_frame.pixels_width) / 2.0).to_i16, ((@rows * sheet_frame.pixels_height) / 2.0).to_i16, tile_width.to_i16, tile_height.to_i16)
      end

      def outside_center?(block : Block)
        x_diff = offset_x - block.real_x
        y_diff = offset_y - block.real_y
        if @cols == 1 && @rows == 1
          x_diff.abs > (half_sheet_frame.cols / view_scale) || y_diff.abs > (half_sheet_frame.cols / view_scale)
        else
          x_diff.abs > half_sheet_frame.cols || y_diff.abs > half_sheet_frame.cols
        end

        frame = half_sheet_frame
        x_amount = (frame.cols - (Window.window.width / frame.tile_width / 2.0)).floor
        y_amount = (frame.rows - (Window.window.height / frame.tile_height / 2.0)).floor
        real_x = offset_x + x_amount
        real_y = offset_y + y_amount
      end

      def center_block=(block : Block)
        @center_block = block

        if @cols == 1 && @rows == 1
        else
        end
      end

      def start_sheet(col : Int16, row : Int16)
        raise SheetOutOfBoundsError.new("#{col}, #{row}") unless in_bounds?(col, row)
        raise SheetAlreadyStartedError.new("#{col}, #{row}") if sheet_started?(col, row)
        raise SheetExistsError.new("#{col}, #{row}") if sheet_exists?(col, row)
        @started_sheets[col] ||= [] of Int16
        @started_sheets[col].push(row)
      end

      def offset_x
        center_block.real_x
      end

      def offset_y
        center_block.real_y
      end

      def container_size
        @cols * @rows
      end

      def started
        @started_sheets.sum { |_, array| array.size }
      end

      def started?
        @started_sheets.sum { |_, array| array.size } > 0
      end

      def full?
        @started_sheets.sum { |_, array| array.size } == size
      end

      def empty?
        @started_sheets.sum { |_, array| array.size } == 0
      end

      def sheet_started?(col : Int16, row : Int16)
        @started_sheets[col]? && @started_sheets[col].includes?(row)
      end

      def in_bounds?(col : Int16, row : Int16)
        col < cols && row < rows && col >= 0 && rows >= 0
      end
    end

    class PixelBook < Book
      @sheets : Hash(Int16, Hash(Int16, PixelSheet)) = {} of Int16 => Hash(Int16, PixelSheet)

      struct PixelSheet < Book::Sheet
        getter sheet : Bytes

        def initialize(@col : Int16, @row : Int16, @book : PixelBook, @sheet : Bytes)
        end
      end

      def sheet(col : Int16, row : Int16)
        raise SheetOutOfBoundsError.new("#{col}, #{row}") unless in_bounds?(col, row)
        raise SheetMissingError.new("#{col},#{row}") unless sheet_exists?(col, row)
        @sheets[col][row]
      end

      def sheet_exists?(col : Int16, row : Int16)
        @sheets[col]? && @sheets[col][row]?
      end

      def finished?
        @sheets.size == container_size
      end

      def finished?
        size == container_size
      end

      def present?
        size > 0
      end

      def size
        @sheets.sum { |_, hash| hash.size }
      end

      def pending?
        started > size
      end

      def create_sheet(col : Int16, row : Int16, pixels : Bytes)
        raise SheetExistsError.new("#{col}, #{row}") if sheet_exists?(col, row)
        @sheets[col] ||= {} of Int16 => PixelSheet
        @sheets[col][row] = PixelSheet.new(col, row, self, pixels)
      end

      def clear
        @sheets.each do |col, rows|
          rows.each do |row, value|
            GC.free value.sheet.to_unsafe.as(Pointer(Void))
            GC.free Pointer(Void).new(value.object_id)
          end
        end
        GC.free Pointer(Void).new(@sheets.object_id)
        @sheets = {} of Int16 => Hash(Int16, PixelSheet)
        7.times do
          GC.collect
        end
      end
    end

    class TextureBook < Book
      @sheets : Hash(Int16, Hash(Int16, TextureSheet)) = {} of Int16 => Hash(Int16, TextureSheet)

      struct TextureSheet < Book::Sheet
        getter sheet : SDL::Texture

        def initialize(@col : Int16, @row : Int16, @book : TextureBook, @sheet : SDL::Texture)
        end

        def clear
          LibSDL.destroy_texture(@sheet.to_unsafe)
        end
      end

      def sheet(col : Int16, row : Int16)
        raise SheetOutOfBoundsError.new("#{col}, #{row}") unless in_bounds?(col, row)
        raise SheetMissingError.new("#{col}, #{row}") unless sheet_exists?(col, row)
        @sheets[col][row]
      end

      def sheet_exists?(col : Int16, row : Int16)
        @sheets[col]? && @sheets[col][row]?
      end

      def finished?
        size == container_size
      end

      def present?
        size > 0
      end

      def size
        @sheets.sum { |_, hash| hash.size }
      end

      def pending?
        started > size
      end

      def create_sheet(col : Int16, row : Int16, texture : SDL::Texture)
        unless col == 0 && row == 0
          raise SheetExistsError.new if sheet_exists?(col, row)
        end
        @sheets[col] ||= {} of Int16 => TextureSheet
        @sheets[col][row] = TextureSheet.new(col, row, self, texture)
      end
    end
  end
end
