module Cryngine
  module Display
    alias AnyGameChar = GameChar | Background

    struct GameChar
      getter color, char

      def initialize(@char : Char, @color : Int32, @spaces : Int32 = 1)
      end

      def to_s(io)
        io << color << @char << spaces
      end

      def spaces
        " " * @spaces
      end

      def color_num
        @color
      end

      def color
        Terminal.color256(color: @color)
      end

      def ==(char : AnyGameChar)
        char.is_a?(GameChar) && @char == char.char && @color == char.color_num
      end
    end
  end
end
