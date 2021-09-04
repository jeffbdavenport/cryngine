require "./screen_buffer"
require "./window"
require "./game_char"

module Cryngine
  module Display
    class GameScreen
      getter rows, cols, window, border_char
      getter top_border, bottom_border, left_border, right_border = true, true, true, true
      getter fill_background = ""
      @border : String?

      # @char_width is the amount of Terminal columns the character will take up
      def initialize(@rows : Int32, @cols : Int32, @border_char : GameChar? = nil, row_offset = 0, col_offset = 0, @char_padding = 1, hide = false, @background : Background = Background.new(color: 255))
        border_size = @border_char.nil? ? 0 : 2
        cols += border_size
        rows += border_size
        @window = Window.new(rows, cols, row_offset, col_offset, hide, true, @char_padding)
        self.top_border = false
        @fill_background = fill_game_screen(@background)
        Terminal::ScreenBuffer.puts(border + fill_background + Terminal.reset_cursor)
      end

      def hide=(hide)
        window.hide = hide
      end

      def border?
        !@border_char.nil?
      end

      def last_row
        rows - 1
      end

      def last_col
        col - 1
      end

      def move_cursor(row, col)
        check(row, col)
        window.move_cursor(row + add_border, col + add_border)
      end

      def print(char : AnyGameChar, row = 0, col = 0)
        check(row, col)
        window.print(char, row + add_border, col + add_border)
      end

      def print(string : String, row = 0, col = 0)
        check(row, col)
        window.print(string, row + add_border, col + add_border)
      end

      def border : String
        border_char = @border_char
        return "" if border_char.nil?
        @border ||= String.build do |io|
          window.cols.times do |col|
            io << window.print(border_char, 0, col)
            io << window.print(border_char, window.last_row, col)
          end
          rows.times do |row|
            io << window.print(border_char, row + 1, 0)
            io << window.print(border_char, row + 1, window.last_col)
          end
          io << Terminal::RESET_FORMAT
        end
      end

      def fill_game_screen(char : Background = @background)
        String.build do |io|
          io << char
          rows.times do |row|
            io << move_cursor(row, 0)
            io << " " * cols * window.char_width
            # cols.times do |col|
            #   fill += print(char, row, col)
            # end
          end
          io << Terminal::RESET_FORMAT
        end
      end

      def top_border=(bool : Bool)
        @border = nil
        @top_border = bool
      end

      def left_border=(bool : Bool)
        @border = nil
        @left_border = bool
      end

      def right_border=(bool : Bool)
        @border = nil
        @right_border = bool
      end

      def bottom_border=(bool : Bool)
        @border = nil
        @bottom_border = bool
      end

      private def add_border
        border? ? 1 : 0
      end

      private def check(row, col)
        raise ArgumentError.new("GameScreen starts at 0,0") unless row >= 0 && col >= 0
        raise "#{row}, #{col} Out of GameScreen bounds" if row > rows || col > cols
      end
    end
  end
end
