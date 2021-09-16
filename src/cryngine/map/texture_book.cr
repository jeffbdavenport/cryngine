module Cryngine
  module Map
    class TextureBook < Book
      @sheets : Hash(Block, TextureSheet) = {} of Block => TextureSheet

      struct TextureSheet < Book::Sheet
        getter sheet : SDL::Texture
        getter center_block : Block

        def initialize(@col : Int16, @row : Int16, @book : TextureBook, @sheet : SDL::Texture, @center_block)
        end

        def clear
          LibSDL.destroy_texture(@sheet.to_unsafe)
        end
      end

      def sheet(col : Int16, row : Int16)
        block = block_for(col, row)
        raise SheetMissingError.new("#{col}, #{row}") unless sheet_exists?(block)
        @sheets[block]
      end

      def sheet(block : Block)
        raise SheetMissingError.new("#{block}: #{block.real}, col,row: #{sheet_col(block.real_x)}, #{sheet_row(block.real_y)}") unless sheet_exists?(block)
        @sheets[block]
      end

      def sheet_exists?(col, row)
        block = block_for(col, row)
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

      # def center_block=(new_center)
      #   return false if center_block == new_center
      #   mutex.synchronize do
      #     @center_block = new_center

      #     # TODO : Remove these two lines if it works
      #     block = block_for(mid_col, mid_row)
      #     raise CenterMismatch.new("new_center: #{new_center} should be equal to block_for(0, 0) #{block}") unless new_center == block

      #     cols.times do |col|
      #       rows.times do |row|
      #         block = block_for(col, row)
      #         if @textures[block.real_x]? && @textures[block.real_x][block.real_y]?
      #           @sheets[col] ||= {} of Int16 => TextureSheet
      #           @sheets[col][row] = TextureSheet.new(col, row, self, @textures[block.real_x][block.real_y])
      #         else
      #           @sheets[col].delete(row) if sheet_exists?(col, row)
      #           @started_sheets[col].delete(row) if sheet_started?(col, row)
      #         end
      #       end
      #     end
      #     Log.debug { " * Started Sheets #{@started_sheets}" }
      #   end
      #   true
      # end

      def create_sheet(col, row, texture : SDL::Texture)
        mutex.synchronize do
          block = block_for(col, row)
          raise SheetNotStarted.new("#{col}, #{row} Tried to create sheet that was not started, was it deleted?") unless sheet_started?(block)
          @sheets[block] = TextureSheet.new(col, row, self, texture, block)
        end
      end
    end
  end
end
