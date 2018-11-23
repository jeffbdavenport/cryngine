# An advanced 3D game engine in development with the goal in mind of convention, speed, and high quality over configuration
require "./cryngine/*"
require "./cryngine/devices/*"
require "./cryngine/display/*"
require "./cryngine/system/*"
require "./cryngine/server/*"
require "logger"

module Cryngine
  VERSION = "0.0.1"
  Log     = System::Log
  alias Loop = System::Loop
end
