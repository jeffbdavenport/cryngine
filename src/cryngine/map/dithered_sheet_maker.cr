module Cryngine
  alias DitheredSheetMaker = Map::DitheredSheetMaker

  module Map
    class DitheredSheetMaker < SheetMaker
      getter made_sheets_channel = Channel(Tuple(Int16, Int16, Bytes))

      def initialize(@map : Map, @layers : Array(Int32), @render_grid = TextureGrid.new(map: @map), concurrent_sheets = 9)
        @made_sheets_channel = Channel(Tuple(Int16, Int16, Bytes)).new(concurrent_sheets)
        @receive_texture_channel = Channel(SDL::Texture).new(concurrent_sheets)

        concurrent_sheets.times do
          Loop.new("made_sheets_receiver_#{i}") do
            col, row, unformatted_sheet = made_sheets_channel.receive

            Log.debug { "Waiting to be allowed to dither sheet" }
            # Renderer.render_print_wait.receive
            bmp_bytes = dither_sheet(unformatted_sheet)

            Renderer.load_surface_channel.send({@receive_texture_channel, bmp_bytes})
            texture = @receive_texture_channel.receive
            render_grid.create_sheet(col, row, texture)
          end
        end
      end

      def create_sheet(pivot_block : Block)
        sheet = make_sheet pivot_block, @layers
        col, row = grid.sheet_for(pivot_block)
        made_sheets_channel.send({col, row, sheet})
      end

      def dither_sheet(pixels : Pixels) : Pixels?
        result_tool = DitherTool.new
        # Log.debug { "Loading Sheet to Dither" }
        result_tool.load_image(pixels)
        # Fiber.yield
        Log.debug { "Cropping Sheet" }
        result_tool.crop frame.pixels_width, frame.pixels_height
        Fiber.yield
        result_tool.scale(@map.scale, frame.pixels_width.to_i, frame.pixels_height.to_i)
        Log.debug { "Scaled Sheet" }
        Fiber.yield
        result_tool.floyd_steinberg
        Log.debug { "Dithered Sheet" }
        # result_tool.save("non-dithered-draft-#{above}.bmp")

        pixels = result_tool.as_bytes
        # IMPORTANT! Clears GBs of memory
        result_tool.cleanup

        pixels
      end
    end
  end
end
