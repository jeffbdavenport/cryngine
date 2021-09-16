module Cryngine
  module MSGP
    class Level
      include MessagePack::Serializable

      property bytes : Bytes
    end
  end
end
