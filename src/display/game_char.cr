require "./game_char_base"

module Cryngine
  module Display
    struct GameChar < GameCharBase
      def initialize(@char : Char, @color : Int32, @background : Int32? = nil)
      end
    end
  end
end
