require "cryngine/exceptions"

module Cryngine
  VERSION = "0.1.0"

  module Display
    alias Player = Map::Player
    alias Sheet = Map::Sheet
    alias Block = Map::Block
    alias PixelBook = Map::PixelBook
    alias TextureBook = Map::TextureBook
    alias Rect = SDL::Rect
  end

  module Map
    alias SheetMaker = Display::SheetMaker
    alias Window = Display::Window
    alias Rect = SDL::Rect
  end

  module Devices
  end

  module System
  end

  module Commands
  end
end
