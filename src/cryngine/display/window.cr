require "./terminal"

module Cryngine
  module Display
    class Window
      class_property windows = [] of Window
      getter rows, cols, row_offset, col_offset
      getter first_row : Int32
      getter first_col : Int32

      def self.resize_terminal
        rows, cols = 0, 0
        windows.select(&.display?).each do |window|
          row_check = window.real_last_row
          # row_check += Loop.loops if Loop.display_loop_counts
          rows = row_check if row_check > rows
          cols = window.real_last_col if window.real_last_col > cols
        end
        Terminal.resize_terminal(rows + 1, cols)
      end

      def initialize(@rows : Int32, @cols : Int32, @row_offset : Int32 = 0, @col_offset : Int32 = 0, @hide = false, resize = true, @char_padding = 1)
        @first_row = @row_offset + 1
        @first_col = @col_offset + 1
        self.class.windows.push(self)
        self.class.resize_terminal if resize
      end

      def char_width
        @char_padding + 1
      end

      def hidden?
        @hide
      end

      def display?
        !@hide
      end

      def get_row(row)
        row + first_row
      end

      def get_col(col)
        col * char_width + first_col
      end

      def last_row
        rows - 1
      end

      def last_col
        cols - 1
      end

      def real_last_row
        get_row(rows) - 1
      end

      def real_last_col
        get_col(cols) - 1
      end

      def move_cursor(row, col)
        raise ArgumentError.new("Window starts at 0,0") if row < 0 || col < 0
        raise "#{row}, #{col} Out of Window bounds" if row > rows || col > cols
        row = get_row(row)
        col = get_col(col)
        Terminal.move_cursor(row, col)
      end

      def print(char : AnyGameChar, row = 0, col = 0)
        "#{move_cursor(row, col)}#{char}"
      end

      def print(string : String, row = 0, col = 0)
        "#{move_cursor(row, col)}#{string}"
      end
    end
  end
end
