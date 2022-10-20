require "../map/grid"
require "../map/sheet"
require "../map/texture_sheet_grid"
require "../map/sheet_grid"
require "../display/renderer"

module Cryngine
  class Map
    class SheetMaker
      getter render_grid : TextureSheetGrid

      @layers : Array(Int32) = [] of Int32

      @top : UInt8?
      @left : UInt8?
      @right : UInt8?
      @bottom : UInt8?

      def self.initialize
      end

      def initialize(map : Map, @layers : Array(Int32), @render_grid : TextureSheetGrid = TextureSheetGrid.new(map: map, view_scale: map.scale, montage: true))
        @map = map
      end

      private def layers
        @map.layers.select { |id, layer| @layers.includes?(id) }
      end

      def grid
        render_grid
      end

      def frame
        grid.sheet_frame
      end

      def half_frame
        grid.half_sheet_frame
      end

      def make_sheet(pivot_block : Block)
        col, row = grid.sheet_for(pivot_block)
        raise SheetAlreadyStartedError.new if grid.sheet_exists?(col, row)
        Log.debug { "Waiting to be allowed to make sheet" }
        # Renderer.render_print_wait.receive
        printables = process_make_sheet pivot_block
        receive_sheet_channel = Channel(Renderer::TextureType).new(1)
        Renderer.render_sheets_channel.send({grid.render_type, receive_sheet_channel, printables})
        receive_sheet_channel.receive
      end

      def create_sheet(pivot_block : Block)
        pixels = make_sheet pivot_block
        col, row = grid.sheet_for(pivot_block)
        sheet = case grid
                when TextureSheetGrid
                  grid.as(TextureSheetGrid).create_sheet(col, row, pixels.as(SDL::Texture))
                else
                  grid.as(SheetGrid).create_sheet(col, row, pixels.as(Pixels))
                end
        top, left, right, bottom = {@top, @left, @right, @bottom}
        # raise SheetMadeEmpty.new("Boundaries are not present for sheet layers: #{@layers} col,row: #{col} #{row} t,l,r,b: #{top}, #{left}, #{right}, #{bottom}") unless top && left && right && bottom
        return unless top && left && right && bottom
        sheet.top = top
        sheet.left = left
        sheet.right = right
        sheet.bottom = bottom

        Log.debug { "Created Sheet: #{col}, #{row}, tlrb: #{{top, left, right, bottom}}" }
      end

      # Make array of printable objects the renderer can understand
      def process_make_sheet(pivot_block : Block, printables = [] of Tuple(SDL::Texture, Rect, Rect))
        # Adjsut the camera so the player is in the center

        @top = nil
        @left = nil
        @right = nil
        @bottom = nil
        screen_cols = frame.cols - 1_u8
        screen_rows = frame.rows - 1_u8

        Log.debug { "Making Sheet: #{pivot_block.real}" }

        @layers.each do |id|
          layer = @map.layers[id]
          0_u8.upto(screen_rows).each do |row|
            real_y = pivot_block.real_y + (row.to_i - grid.row_adjust)

            0_u8.upto(screen_cols).each do |col|
              real_x = pivot_block.real_x + (col.to_i - grid.col_adjust)
              block = Block.from_real(real_x, real_y)

              layer.chunks.each do |chunk|
                next unless chunk.x == block.x && chunk.y == block.y && chunk.data[block.col]?

                rows = chunk.data[block.col]
                next unless rows[block.row]?
                modify_boundary(col, row)
                sprite = rows[block.row]
                tile = Map::Tile.new(@map, block.col, block.row, sprite, chunk)
                rect = SDL::Rect.new((col.to_i * @map.tile_width).to_i, (row.to_i * @map.tile_height).to_i, tile.tileset.tile_width.to_i, tile.tileset.tile_height.to_i)

                printables.push({tile.tileset.texture, rect, tile.clip})
              end
            end
          end
        end
        Log.debug { "Generated Sheet #{pivot_block.real}" }

        printables
      end

      private def modify_boundary(col : UInt8, row : UInt8)
        top, left, bottom, right = {@top, @left, @bottom, @right}
        @top ||= row
        @top = row if top && row < top
        @left ||= col
        @left = col if left && col < left
        @bottom ||= row
        @bottom = row if bottom && row > bottom
        @right ||= col
        @right = col if right && col > right
      end
    end
  end
end
