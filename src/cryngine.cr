require "./cryngine/*"
require "./cryngine/devices/*"
require "./cryngine/display/*"
require "./cryngine/system/*"
require "./cryngine/server/*"
require "./cryngine/client/*"
require "./cryngine/msgpack/*"

module Cryngine
  VERSION = "0.1.0"
  Log     = System::Log
  alias Loop = System::Loop

  module Display
  end

  module Devices
  end

  module System
  end

  class Server
  end

  class Client
  end
end
