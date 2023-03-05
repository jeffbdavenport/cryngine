module Cryngine
  class Map
    abstract struct Sheet
      alias Window = Display::Window
      getter grid

      property top, left, right, bottom

      @top : UInt8 = 0_u8
      @left : UInt8 = 0_u8
      @right : UInt8 = 0_u8
      @bottom : UInt8 = 0_u8

      def offset_x
        center_block.real_x
      end

      def offset_y
        center_block.real_y
      end

      def self.coord_from_offset(real_xy, center_block_coord, tile_wh, minus_xy)
        coord = real_xy * tile_wh
        offset = center_block_coord * tile_wh
        coord - offset - minus_xy
      end

      def self.window_edge(sheet_pixels_wh, windw_wh)
        (sheet_pixels_wh / 2.0) - (windw_wh / 2.0)
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

      def x_from_offset(real_x, tile_width, minus_x)
        self.class.coord_from_offset(real_x, offset_x, tile_width, minus_x) # - grid.col_adjust)
      end

      def y_from_offset(real_y, tile_height, minus_y)
        self.class.coord_from_offset(real_y, offset_y, tile_height, minus_y) # - grid.row_adjust)
      end

      # def sheet_x_offset(sheet_pixels_width)
      #   @col*(grid.x_between_distance/view_scale)
      # end

      # def sheet_y_offset(sheet_pixels_height)
      #   @row*(grid.y_between_distance/view_scale)
      # end

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

      def clip_rect_x(real_x, minus_x)
        left_edge = window_left_edge(grid.sheet_frame.pixels_width, grid.sheet_frame.tile_width, (Window.window.width / view_scale))
        x_offset = x_from_offset(real_x, grid.sheet_frame.tile_width, minus_x)
        # sheet_x_offset = sheet_x_offset(grid.sheet_frame.pixels_width)

        # puts "L: #{left_edge}, #{sheet_x_offset}, #{x_offset}"
        (left_edge + x_offset).to_i
      end

      def clip_rect_y(real_y, minus_y)
        top_edge = window_top_edge(grid.sheet_frame.pixels_height, (Window.window.height / view_scale))
        y_offset = y_from_offset(real_y, grid.sheet_frame.tile_height, minus_y)
        # sheet_y_offset = sheet_y_offset(grid.sheet_frame.pixels_height)

        # puts "T: #{left_edge}, #{sheet_x_offset}, #{x_offset}"
        (top_edge + y_offset - (Player.player_height / view_scale)).to_i
      end

      def view_rect_x(real_x, minus_x)
        left_edge = window_left_edge(grid.sheet_frame.pixels_width*view_scale, grid.sheet_frame.tile_width, (Window.window.width))
        x_offset = x_from_offset(real_x, grid.map.scaled_tile_width, minus_x)
        # sheet_x_offset = sheet_x_offset(grid.sheet_frame.pixels_width)

        # puts "L: #{left_edge}, #{sheet_x_offset}, #{x_offset}"
        -(left_edge + x_offset).to_i
      end

      def view_rect_y(real_y, minus_y)
        top_edge = window_top_edge(grid.sheet_frame.pixels_height*view_scale, (Window.window.height))
        y_offset = y_from_offset(real_y, grid.map.scaled_tile_height, minus_y)
        # sheet_y_offset = sheet_y_offset(grid.sheet_frame.pixels_height)

        # puts "T: #{left_edge}, #{sheet_x_offset}, #{x_offset}"
        -(top_edge + y_offset - (Player.player_height / view_scale)).to_i
      end

      def clip_rect_width(clip_rect_x)
        print_width(clip_rect_x, grid.sheet_frame.pixels_width, (Window.window.width / view_scale)).to_i
      end

      def clip_rect_height(clip_rect_y)
        print_height(clip_rect_y, grid.sheet_frame.pixels_height, (Window.window.height / view_scale)).to_i
      end

      def view_scale
        grid.view_scale
      end

      def full_image_view_rect(block : Block, minus_x = 0, minus_y = 0) : Tuple(Rect, Rect)
        view_x = view_rect_x(block.real_x, minus_x)
        view_y = view_rect_y(block.real_y, minus_y)

        view = Rect.new(view_x, view_y, (grid.sheet_frame.pixels_width*view_scale).to_i, (grid.sheet_frame.pixels_height*view_scale).to_i)
        clip = Rect.new(0, 0, grid.sheet_frame.pixels_width.to_i, grid.sheet_frame.pixels_height.to_i)
        {view, clip}
      end

      def rects_from(block : Block, minus_x = 0, minus_y = 0) : Tuple(Rect, Rect)
        rect_x = clip_rect_x(block.real_x, minus_x/view_scale)
        rect_y = clip_rect_y(block.real_y, minus_y/view_scale)

        clip_width = clip_rect_width(rect_x)
        clip_height = clip_rect_height(rect_y)

        view_x = view_rect_x(block.real_x, minus_x)
        view_y = view_rect_y(block.real_y, minus_y)

        rect_x = 0 if rect_x < 0
        rect_y = 0 if rect_y < 0
        clip = Rect.new(rect_x - 26 * 32, rect_y - 26 * 32 - 16, clip_width, clip_height)

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
  end
end
