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

    # Sheets
    class SheetOutOfBoundsError < Exception; end

    class SheetExistsError < Exception; end

    class SheetMissingError < Exception; end

    class SheetAlreadyStartedError < Exception; end
  end
end
