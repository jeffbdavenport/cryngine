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
  include Exceptions

  module Display
  end

  alias Pixels = Bytes

  alias Rect = SDL::Rect

  alias Player = Map::Player
  alias Sheet = Map::Sheet
  alias Block = Map::Block
  alias SheetGrid = Map::SheetGrid
  alias TextureSheetGrid = Map::TextureSheetGrid
  alias Chunk = Map::Chunk
  alias CollisionMap = Map::CollisionMap
  alias Collider = Map::Collider
  alias SheetMaker = Map::SheetMaker

  alias Window = Display::Window
  alias Renderer = Display::Renderer
  alias DitherTool = Display::DitherTool

  alias Keyboard = Devices::Keyboard

  class Map
  end

  module Devices
  end

  module System
  end

  module Commands
  end
end
