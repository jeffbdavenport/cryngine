module Cryngine
  module Display
    module Terminal
      class Color
        BRIGHT = [7, 15, 50, (85..87).to_a, (117..123).to_a, (154..159).to_a, (182..195).to_a, (218..231).to_a, (249..255).to_a].flatten
        SOLID  = (1..255).to_a - BRIGHT
      end
    end
  end
end
