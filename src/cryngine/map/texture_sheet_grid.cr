module Cryngine
  class Map
    class TextureSheetGrid < Grid
      @sheets : Hash(Block, TextureSheet) = {} of Block => TextureSheet

      @render_type = Renderer::RenderTypes::Texture

      struct TextureSheet < Sheet
        getter sheet : SDL::Texture
        getter center_block : Block

        def initialize(@col : Int16, @row : Int16, @grid : TextureSheetGrid, @sheet : SDL::Texture, @center_block)
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

      def sheet_exists?(col : Int16, row : Int16)
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

      def create_sheet(col : Int16, row : Int16, texture)
        raise InvalidTextureType.new("Texture cannot be pixels for a TextureSheetGrid") if texture.is_a?(Pixels)
        mutex.synchronize do
          block = block_for(col, row)
          raise SheetNotStarted.new("#{col}, #{row} Tried to create sheet that was not started, was it deleted?") unless sheet_started?(block)
          @sheets[block] = TextureSheet.new(col, row, self, texture, block)
        end
      end
    end
  end
end
