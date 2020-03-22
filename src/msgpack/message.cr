require "msgpack"

module Cryngine
  module MSGP
    class Message
      include MessagePack::Serializable

      property command : String
      property data : Slice(UInt8)
    end

    class Connect
      include MessagePack::Serializable

      property email : String
    end

    class MoveBlock
      include MessagePack::Serializable
    end

    class MovePlayer
      include MessagePack::Serializable

      property coords : Tuple(UInt8, UInt8)
      property shard_coords : Tuple(Int32, Int32)
    end

    class NewObjects
      include MessagePack::Serializable

      property references : Array(NamedTuple(object_id: UInt64, char: String, spaces: Int32, color: Int32, level: Int32))
      property objects : Array(NamedTuple(object_id: UInt64, name: String, level: Int32, reference: UInt64))
    end

    class CreateShard
      include MessagePack::Serializable

      property shard_map : Hash(UInt64, Hash(UInt8, Array(UInt8)))
      property shard_coords : Tuple(Int32, Int32)
    end
  end
end
