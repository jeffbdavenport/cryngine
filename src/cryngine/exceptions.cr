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

    class SheetNotStarted < Exception; end

    class CenterMismatch < Exception; end

    class SheetWidthZero < Exception; end

    class SheetMadeEmpty < Exception; end

    class MontageBoundsMissing < Exception; end

    # Grid
    class InvalidTextureType < Exception; end

    # Renderer

    class RenderInvalidType < Exception; end

    # Sheets
  end
end
