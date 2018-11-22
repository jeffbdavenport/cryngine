# An advanced 3D game engine in development with the goal in mind of convention, speed, and high quality over configuration
require "cryngine/*"
require "cryngine/devices/*"
require "cryngine/display/*"
require "cryngine/system/*"

module Cryngine
  VERSION = "0.0.1"
  Log     = System::Log
  alias Loop = System::Loop

  # module Display
  # end

  # module Devices
  # end

  # module System
  # end

  # module Server
  # end
end
