module Cryngine
  module Display
    module SheetMaker
      # def initialize()

      @@dither_tool : DitherTool
      @@dither_tool = uninitialized DitherTool
      @@dither = false

      def self.dither(dither_colors_image)
        raise "Already set Dither" if @@dither
        @@dither = true
        @@dither_tool = DitherTool.new(dither_colors_image)
        nil
      end

      def self.make_sheet(col : Int16, row : Int16, start_block : Map::Block)
        Window.renderer.clear
        screen_cols = (Window.window.width / Map.tile_width).floor.to_i
        screen_rows = (Window.window.height / Map.tile_height).floor.to_i
        puts "Screen: #{screen_cols}, #{screen_rows}"

        0.upto(screen_cols).each do |col|
          0.upto(screen_rows).each do |row|
            real_x = start_block.real_x + (col.to_i - Map::Player.unscaled_col.to_i).to_i64
            real_y = start_block.real_y + (row.to_i - Map::Player.unscaled_row.to_i).to_i64
            # puts "#{real_x}, #{real_y}"
            block = Map::Block.from_real(real_x, real_y)

            Map.layers.keys.sort.each do |id|
              layer = Map.layers[id]
              layer.chunks.each do |chunk|
                next unless chunk.x == block.x && chunk.y == block.y && chunk.data[block.col]?

                rows = chunk.data[block.col]
                next unless rows[block.row]?
                sprite = rows[block.row]
                tile = Map::Tile.new(block.col, block.row, sprite, chunk)

                rect = SDL::Rect.new((col * Map.tile_width).to_i, (row * Map.tile_height).to_i, Map.tile_width, Map.tile_height)
                Window.renderer.viewport = rect
                Window.renderer.copy(Window.textures[tile.tileset.name], tile.clip)
              end
            end
          end
        end

        Window.copy_renderer_to_surface

        surface = nil
        if @@dither
          # Each pixel
          pixels = Window.surface_as_bytes(Window.surface)

          @@dither_tool.load_image(pixels)
          @@dither_tool.scale(Map.scale, Window.window.width, Window.window.height)
          @@dither_tool.floyd_steinberg

          @@dither_tool.as_bytes do |p|
            rw = LibSDL.rw_from_mem(p, p.size)
            surface = LibSDL.load_bmp_rw(rw, 1)
          end
          @@dither_tool.save("dithered.bmp")
        end

        if surface
          texture = LibSDL.create_texture_from_surface(Window.renderer, surface)
          LibSDL.free_surface surface
          Map::Sheet.new(col, row, texture)
          true
        else
          SDL::Error.new("Unable to load image")
          false
        end
      end

      def self.cleanup
        @@dither_tool.cleanup if @@dither
      end
    end
  end
end
