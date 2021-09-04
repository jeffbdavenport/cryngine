require "msgpack"

module Cryngine
  module MSGP
    class Message
      include MessagePack::Serializable

      property c : UInt8
      property d : Slice(UInt8)
    end
  end
end
