module Cryngine
  module Map
    class PixelBook < Book
      @sheets : Hash(Block, PixelSheet) = {} of Block => PixelSheet

      struct PixelSheet < Book::Sheet
        getter sheet : Bytes
        getter center_block : Block

        def initialize(@col : Int16, @row : Int16, @book : PixelBook, @sheet : Bytes, @center_block)
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

      def sheet_exists?(col, row)
        @sheets[block_for(col, row)]?
      end

      def sheet_exists?(block : Block)
        @sheets[block]?
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

      def create_sheet(col, row, pixels : Bytes)
        mutex.synchronize do
          block = block_for(col, row)
          raise SheetNotStarted.new("#{col}, #{row} Tried to create sheet that was not started, was it deleted?") unless sheet_started?(block)
          @sheets[block] = PixelSheet.new(col, row, self, pixels, block)
        end
      end

      # def clear
      #   mutex.synchronize do
      #     @started_sheets.clear
      #     @sheets.each do |col, rows|
      #       rows.each do |row, value|
      #         GC.free value.sheet.to_unsafe.as(Pointer(Void))
      #       end
      #     end
      #     @sheets.clear
      #     7.times do
      #       GC.collect
      #     end
      #   end
      #   Log.debug { "Cleared PixelBook" }
      # end
    end
  end
end
