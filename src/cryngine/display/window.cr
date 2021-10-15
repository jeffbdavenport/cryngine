require "magickwand-crystal"
require "sdl"
require "sdl/lib_img"
require "../map/tile"
require "./dither_tool"
require "../map/block"
require "../map/player"
require "../map/sheet"
require "../map/sheet_maker"
require "../display/renderer"
require "../system/loop"
require "../input"

macro define_pixelformat(type, order, layout, bits, bytes)
 ((1 << 28) | ({{type}} << 24) | ({{order}} << 20) | ({{layout}} << 16) | ({{bits}} << 8) | ({{bytes}} << 0))
end

class Channel(T)
  @queue : Deque(T) = Deque(T).new

  def waiting?
    !@receivers.empty?
  end

  def empty?
    @queue.empty?
  end
end

module Cryngine
  module Display
    module Window
      class_property window : SDL::Window
      @@window = uninitialized SDL::Window
      @@sheet = uninitialized Map::Sheet
      WIDTH  = 1680
      HEIGHT =  880
      FPS    =  240
      SPEED  = Input::SPEED

      class_getter update_channel = Channel(Nil).new(2)
      class_getter cleanup_channel = Channel(Nil).new
      class_getter exit_channel = Channel(Nil).new
      class_getter mutex = Mutex.new
      @@exit = false

      def self.initialize(game_title : String, width = WIDTH, height = HEIGHT, flags : SDL::Window::Flags = SDL::Window::Flags::SHOWN)
        LibIMG.init LibIMG::Init::PNG

        Renderer.initialize(game_title, width, height, flags: flags)
        # Loop.new(:map_checker, same_thread: true) do
        #   col, row = map_checker_channel.receive
        #   # from_col, from_row = map_checker_channel.receive

        #   # [0, -1, 1].each do |col|
        #   #   [0, -1, 1].each do |row|
        #   # col = col.to_i16 + from_col
        #   # row = row.to_i16 + from_row

        #   next if Renderer.render_book.sheet_exists?(col, row)
        #   # Log.debug { "^ Check map start sheet from: #{col}, #{row}" }

        #   book = if SheetMaker.dither
        #            SheetMaker.pixel_book
        #          else
        #            Renderer.render_book
        #          end
        #   next if book.sheet_started?(col, row)

        #   if SheetMaker.dither
        #     SheetMaker.pixel_book_above.start_sheet(col, row)
        #     SheetMaker.pixel_book_below.start_sheet(col, row)
        #   else
        #     Renderer.render_book_above.start_sheet(col, row)
        #     Renderer.render_book_below.start_sheet(col, row)
        #   end

        #   Log.debug { "Started sheet #{col}, #{row}" }

        #   block = Renderer.render_book.block_for(col, row)

        #   SheetMaker.sheet_maker_channel.send({col, row, block})
        #   #   end
        #   # end
        # end
        spawn do
          exit_channel.receive
          # SheetMaker.cleanup
          @@exit = true
        end

        true
      end

      # UPDATE
      def self.rpg_update_loop(grid : TextureSheetGrid)
        Renderer.wait_for_render(grid, 0, 0)

        # until grid.sheet_exists?(0, 0) && grid.sheet_exists?(0, 0)
        #   sleep 1.milliseconds
        # end

        Input.rpg_2D_movement(grid)
        last_frame = Time.monotonic.total_seconds
        prev_x = -1.0
        prev_y = -1.0

        # Bypass waiting for renderer on first frame
        update_channel.send(nil)
        printed = false

        loop do
          break if @@exit

          current = Time.monotonic.total_seconds
          sleep_amount = ((1/FPS) - (current - last_frame))
          if sleep_amount.positive?
            # Log.debug { "Sleep - #{sleep_amount}" }
            usleep(sleep_amount)
            slept = true
          end
          Log.debug { "Did not sleep" } unless slept

          # Wait for Renderer to finish printing
          update_channel.receive

          player_block = mutex.synchronize do
            Player.block
          end

          printables = [] of Tuple(Rect, SDL::Texture, Rect?)

          current = Time.monotonic.total_seconds
          # (time = current - m_time)
          last_frame = current

          if printed && Input.minus_x == 0 && Input.minus_y == 0 && Input.x_velocity == 0 && Input.y_velocity == 0
            Renderer.render_channel.send(printables)
            next
          end

          prev_x = Input.minus_x
          prev_y = Input.minus_y

          yield(printables, player_block, current, Input.minus_x.round.to_i16, Input.minus_y.round.to_i16)

          # if printables == false
          #   exit_channel.send(nil)
          #   next
          # end

          Renderer.render_channel.send(printables)

          Input.after_print_player_move
          printed = true
        end
      end
    end
  end
end
