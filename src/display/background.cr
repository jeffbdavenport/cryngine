module Cryngine
  module Display
    struct Background
      def initialize(@color : Int32)
      end

      def to_s(io)
        io << color
      end

      def color
        Terminal.color256(background: true, color: @color)
      end

      def color_num
        @color
      end

      def ==(char : AnyGameChar)
        char.is_a?(Background) && @color == char.color_num
      end
    end
  end
end
