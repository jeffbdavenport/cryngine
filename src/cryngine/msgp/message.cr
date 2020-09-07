require "msgpack"

module Cryngine
  module MSGP
    class Message
      include MessagePack::Serializable

      property c : Int16
      property d : Slice(UInt8)
    end
  end
end
