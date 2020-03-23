module Cryngine
  module Exceptions
    class WindowOverlapError < Exception
    end

    class BlockCreateError < Exception
    end

    class ObjectAddError < Exception
    end

    class ObjectNotFound < Exception
    end

    class ShardExists < Exception
    end
  end
end
