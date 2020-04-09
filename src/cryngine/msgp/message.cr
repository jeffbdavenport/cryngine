require "msgpack"

module Cryngine
  module MSGP
    class Message
      include MessagePack::Serializable

      property command : String
      property data : Slice(UInt8)
    end
  end
end
