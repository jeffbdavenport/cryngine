require "cryngine/exceptions"

ENV["EVENT_PRECISE_TIMER"] = "1"
ENV["CRYSTAL_WORKERS"] = "16"

lib C
  fun usleep(useconds_t : Int32) : Int32
end

USLEEP = 1_000_000

def usleep(time)
  C.usleep (time * USLEEP).to_i
end

module Cryngine
  VERSION = "0.1.0"

  module Display
  end

  alias Rect = SDL::Rect

  alias Player = Map::Player
  alias Sheet = Map::Sheet
  alias Block = Map::Block
  alias PixelBook = Map::PixelBook
  alias TextureBook = Map::TextureBook
  alias Chunk = Map::Chunk
  alias CollisionMap = Map::CollisionMap
  alias Collider = Map::Collider

  alias SheetMaker = Display::SheetMaker
  alias Window = Display::Window
  alias Renderer = Display::Renderer

  alias Keyboard = Devices::Keyboard

  module Map
  end

  module Devices
  end

  module System
  end

  module Commands
  end
end
