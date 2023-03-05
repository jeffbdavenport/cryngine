require "./sheet_maker"

module Cryngine
  alias MontageMaker = Map::MontageMaker
  alias DitherTool = Display::DitherTool
  alias Renderer = Display::Renderer
  alias SheetMaker = Map::SheetMaker

  class Map
    class MontageMaker < SheetMaker
      getter grid : SheetGrid

      @dither : Bool

      getter render_grid : TextureSheetGrid
      @render_grid = uninitialized TextureSheetGrid

      @map_size : UInt16 # = 0_u16
      @bounds : Tuple(Int32, Int32, Int32, Int32, Int32, Int32)?

      def initialize(map : Map, @layers : Array(Int32), @grid = SheetGrid.new(map: map, montage: true, centered: false, center_block: Block.from_real(0, 0)), @dither = false)
        @map = map
        puts "Initializing render_grid"
        @render_grid = TextureSheetGrid.new(map, montage: true, centered: false, center_block: Block.from_real(0, 0))
        @montage_channel = Channel(Nil).new(1)
        @receive_texture_channel = Channel(SDL::Texture).new(1)

        start_col, start_row, end_col, end_row = start_end_for_all
        rows = (end_col - start_col).abs + 1
        cols = (end_row - start_row).abs + 1
        @map_size = (rows * cols).to_u16

        Loop.new(:made_sheets_receiver) do
          @montage_channel.receive

          Log.debug { "Waiting to be allowed to Create Montage" }
          # Renderer.render_print_wait.receive
          puts "Started"
          bmp_bytes = montage_full
          render_grid.start_sheet(0_u16, 0_u16)

          Renderer.load_surface_channel.send({@receive_texture_channel, bmp_bytes})
          texture = @receive_texture_channel.receive
          render_grid.create_sheet(0_u16, 0_u16, texture)
        end
      end

      def generate_all
        start_col, start_row, end_col, end_row = start_end_for_all
        start_col.upto(end_col).each do |col|
          start_row.upto(end_row).each do |row|
            grid.start_sheet(col, row)
            Log.debug { "Started #{col}, #{row}" }
            block = grid.block_for(col, row)
            spawn do
              create_sheet(block)
              Log.debug { "Created #{col}, #{row}" }
            end
          end
        end
      end

      def create_sheet(pivot_block : Block)
        super
        puts "#{grid.size}:#{@map_size}"
        if grid.size == @map_size
          @montage_channel.send(nil)
        end
      end

      def start_end_for_all
        min_x = (@map.layers.values.map(&.startx).min)
        min_y = (@map.layers.values.map(&.starty).min)

        start_col = grid.sheet_col min_x
        start_row = grid.sheet_col min_y
        max_x = (@map.layers.values.map { |value| value.chunks.map(&.x).max * Chunk.width }.max + Chunk.width)
        max_y = (@map.layers.values.map { |value| value.chunks.map(&.y).max * Chunk.height }.max + Chunk.height)
        end_col = grid.sheet_col max_x
        end_row = grid.sheet_row max_y
        {start_col, start_row, end_col, end_row}
      end

      def montage_full
        montage(*start_end_for_all)
      end

      def get_bounds(start_col, start_row, end_col, end_row) : Tuple(Int16, Int16, Int16, Int16)
        top = nil
        left = nil
        right = nil
        bottom = nil

        start_row.to_i16.upto(end_row.to_i16) do |row|
          cur_row = row - start_row
          start_col.to_i16.upto(end_col.to_i16) do |col|
            cur_col = row - start_row

            sheet = grid.sheet(col, row)
            top_edge = cur_row * sheet.top
            left_edge = cur_col * sheet.left
            right_edge = cur_col * sheet.right
            bottom_edge = cur_row * sheet.bottom

            puts "Edges: #{{top_edge, left_edge, right_edge, bottom_edge}}"
            top ||= top_edge
            top = top_edge if top_edge < top
            left ||= left_edge
            left = left_edge if left_edge < left
            right ||= right_edge
            right = right_edge if right_edge > right
            bottom ||= bottom_edge
            bottom = bottom_edge if bottom_edge > bottom
          end
        end
        raise MontageBoundsMissing.new("Bounds missing for montage: t,l,r,b: #{top}, #{left}, #{right}, #{bottom}") unless top && left && right && bottom
        {top, left, right, bottom}
      end

      def get_bounds_pixels(start_col, start_row, end_col, end_row) : Tuple(Int32, Int32, Int32, Int32, Int32, Int32)
        top, left, right, bottom = get_bounds(start_col, start_row, end_col, end_row)
        top = top.to_i * grid.sheet_frame.tile_height
        left = left.to_i * grid.sheet_frame.tile_width
        right = right.to_i * grid.sheet_frame.tile_width
        bottom = bottom.to_i * grid.sheet_frame.tile_height

        width = right - left
        height = bottom - top
        {width, height, top, left, right, bottom}
      end

      def set_bounds(width, height, top, left, right, bottom)
        @bounds = {width, height, top, left, right, bottom}
      end

      def montage(start_col, start_row, end_col, end_row, dither = false)
        rows = (end_col - start_col).abs + 1
        cols = (end_row - start_row).abs + 1

        result_tool = DitherTool.new

        start_row.upto(end_row) do |row|
          start_col.upto(end_col) do |col|
            Log.debug { "Loading sheet: #{col}, #{row}" }
            sheet = grid.sheet(col, row)
            # col , row= grid.sheet_for(sheet)
            # sheet = grid.sheet(col, row)
            result_tool.load_image(sheet.sheet)
            # wand, width, height, x, y
            LibMagick.magickCropImage(result_tool.wand, grid.sheet_frame.pixels_width, grid.sheet_frame.pixels_height, 0, 0)
            # result_tool.save("#{@layers}-#{col}.#{row}.bmp")
          end
        end
        # grid.clear
        draw = LibMagick.acquireDrawingWand(nil, nil)

        wand = LibMagick.magickMontageImage result_tool.wand, draw, "#{rows}x#{cols}", nil, LibMagick::MontageMode::ConcatenateMode, nil

        LibMagick.destroyDrawingWand draw
        result_tool.cleanup
        Log.debug { "Created Montage" }
        result_tool = DitherTool.new(wand)

        puts "bounds: #{@bounds}, GetBoundsPixels: #{{start_col, start_row, end_col, end_row}}"
        bounds = @bounds
        # width, height, top, left, right, bottom = if bounds
        #                                             bounds
        #                                           else
        #                                             get_bounds_pixels(start_col, start_row, end_col, end_row)
        #                                           end
        # puts "#{get_bounds_pixels(start_col, start_row, end_col, end_row)}"
        # LibMagick.magickCropImage(result_tool.wand, width, height, left, top)

        if @dither
          # puts "w,h: #{(width * @map.scale).to_i}, #{(height * @map.scale).to_i}"
          # @render_grid = TextureSheetGrid.new(@map, width: (width * @map.scale).to_i, height: (height * @map.scale).to_i, tile_height: (@map.tile_height * @map.scale).to_u8, tile_width: (@map.tile_width * @map.scale).to_u8, montage: true, centered: false, center_block: Block.from_real(0, 0))
          @render_grid = TextureSheetGrid.new(@map, width: (@map.width * @map.tile_width).to_i, height: (@map.height * @map.tile_height).to_i, tile_height: (@map.tile_height * @map.scale).to_u8, tile_width: (@map.tile_width * @map.scale).to_u8, montage: true, centered: false, center_block: Block.from_real(0, 0))
          result_tool.scale(1.0, @map.width.to_i * @map.tile_width, @map.height.to_i * @map.tile_height)

          Log.debug { "Scaled Montage" }
          Fiber.yield
          result_tool.floyd_steinberg
          Log.debug { "Dithered Montage" }
          # result_tool.save("dithered-draft-#{start_col}-#{start_row}.bmp")
        else
          @render_grid = TextureSheetGrid.new(@map, width: 156 * 32, height: 108 * 32, view_scale: @map.scale, montage: true, centered: false, center_block: Block.from_real(0, 0))

          # result_tool.scale(@map.scale, width, height)
          result_tool.save("montage-draft-#{@layers}.bmp")
          # result_tool.scale(1.0, @map.width.to_i * @map.tile_width, @map.height.to_i * @map.tile_height)
        end

        # mutex.synchronize do
        bytes = result_tool.as_bytes
        # IMPORTANT! Clears GBs of memory
        result_tool.cleanup

        bytes
        # end
      end
    end
  end
end
