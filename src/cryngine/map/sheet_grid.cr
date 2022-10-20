module Cryngine
  class Map
    class SheetGrid < Grid
      @sheets : Hash(Block, PixelSheet) = {} of Block => PixelSheet

      struct PixelSheet < Sheet
        getter sheet : Pixels
        getter center_block : Block

        def initialize(@col : Int16, @row : Int16, @grid : SheetGrid, @sheet : Pixels, @center_block)
        end
      end

      def sheet(col : Int16, row : Int16)
        block = block_for(col, row)
        raise SheetMissingError.new("#{col}, #{row}") unless sheet_exists?(block)
        @sheets[block]
      end

      def sheet(block : Block)
        raise SheetMissingError.new("#{block}") unless sheet_exists?(block)
        @sheets[block]
      end

      def sheet_exists?(col, row) : Bool
        @sheets[block_for(col, row)]? ? true : false
      end

      def sheet_exists?(block : Block) : Bool
        @sheets[block]? ? true : false
      end

      def present?
        size > 0
      end

      def size
        @sheets.size
      end

      def pending?
        started > size
      end

      def finished?(count)
        @sheets.size == count
      end

      def create_sheet(col : Int16, row : Int16, pixels : Pixels)
        mutex.synchronize do
          block = block_for(col, row)
          raise SheetNotStarted.new("#{col}, #{row} Tried to create sheet that was not started, was it deleted?") unless sheet_started?(block)
          @sheets[block] = PixelSheet.new(col, row, self, pixels, block)
        end
      end
    end
  end
end
