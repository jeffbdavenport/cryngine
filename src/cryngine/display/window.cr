require "magickwand-crystal"
require "sdl"
require "sdl/lib_img"
require "../map/tile"
require "../event"
require "./dither_tool"
require "../map/block"
require "../map/player"
require "../map/sheet"
require "../display/sheet_maker"
require "../display/renderer"
require "../system/loop"

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
      class_getter sheet : Map::Sheet
      @@window = uninitialized SDL::Window
      @@sheet = uninitialized Map::Sheet
      WIDTH        = 1680
      HEIGHT       =  880
      BIT_DEPTH    =   24
      SPEED        =  200
      FPS          =  120
      BOTH_XY_MOVE =  0.8
      # BOTH_XY_MOVE = 0.7066666666666667

      class_getter update_channel = Channel(Nil).new(2)
      class_getter map_checker_channel = Channel(Tuple(Int16, Int16)).new
      class_getter cleanup_channel = Channel(Nil).new
      class_getter exit_channel = Channel(Nil).new
      class_getter mutex = Mutex.new
      class_property minus_x : Float64 = 0.0
      class_property minus_y : Float64 = 0.0
      class_property x_amount : Int16 = 0_i16
      class_property y_amount : Int16 = 0_i16

      # @@mutex = Mutex.new
      class_property moved_time : Float64 = Time.monotonic.total_seconds

      def self.initialize(game_title : String)
        Cryngine::Event.initialize
        Devices::Keyboard.initialize

        LibIMG.init LibIMG::Init::PNG

        Renderer.initialize(game_title, WIDTH, HEIGHT)

        # (unused, w, h, bd, rmask, gmask, bmask, amask)
        # surface = LibSDL.create_rgb_surface(0, surf_width, surf_height, BIT_DEPTH, 0xff000000, 0x00ff0000, 0x0000ff00, 0)

        Loop.new(:map_checker) do
          col, row = map_checker_channel.receive
          # from_col, from_row = map_checker_channel.receive

          # [0, -1, 1].each do |col|
          #   [0, -1, 1].each do |row|
          #     col = col.to_i16 + from_col
          #     row = row.to_i16 + from_row

          next if Renderer.render_book.sheet_exists?(col, row)
          # Log.debug { "^ Check map start sheet from: #{col}, #{row}" }

          book = if SheetMaker.dither
                   SheetMaker.pixel_book
                 else
                   Renderer.render_book
                 end
          next if book.sheet_started?(col, row)

          book.start_sheet(col, row)
          Log.debug { "Started sheet #{col}, #{row}" }

          block = Renderer.render_book.block_for(col, row)

          SheetMaker.sheet_maker_channel.send({col, row, block})
          #   end
          # end
        end

        # Wait for spawns to all initialize here
        update_channel.receive
        map_checker_channel.send({0_i16, 0_i16})

        book = if SheetMaker.dither
                 SheetMaker.pixel_book
               else
                 Renderer.render_book
               end

        until Renderer.render_book.sheet_exists?(0, 0)
          sleep 1.microsecond
          Renderer.render_sheets_channel_wait.send(nil) if Renderer.render_sheets_channel_wait.waiting?
        end

        speed = SPEED/book.view_scale

        input_frames = 0
        # INPUT
        Loop.new(:input) do
          unless minus_x == 0 && minus_y == 0
            usleep 500.microsecond
            next
          end
          key_down = Keyboard.key_down.dup
          key_press = Keyboard.key_press.dup
          # puts "#{key_down} : #{key_press}"
          Keyboard.clear_move_press

          if key_down[:left] || key_press[:left]
            self.x_amount = -1
          elsif key_down[:right] || key_press[:right]
            self.x_amount = 1
          else
            self.x_amount = 0
          end

          if key_down[:up] || key_press[:up]
            self.y_amount = -1
          elsif key_down[:down] || key_press[:down]
            self.y_amount = 1
          else
            self.y_amount = 0
          end

          if y_amount == 0 && x_amount == 0
            usleep 500.microsecond
          else
            mutex.synchronize do
              Map::Player.move(Renderer.render_book, x_amount, y_amount)
              self.moved_time = Time.monotonic.total_seconds
              self.minus_x = (x_amount * Renderer.render_book.sheet_frame.tile_width).to_f
              self.minus_y = (y_amount * Renderer.render_book.sheet_frame.tile_height).to_f
            end

            # TODO : Sleep longer if moving both direcitons
            usleep(Renderer.render_book.sheet_frame.tile_width/speed)
          end
        end

        started = false
        count = 0
        start_time = Time.monotonic.total_seconds
        delta = Time.monotonic.total_seconds
        last_print_time = Time.monotonic.total_seconds

        last_frame = Time.monotonic.total_seconds
        prev_x = 0.0
        prev_y = 0.0
        total_frames = 0

        frame_checker = Time.monotonic.total_seconds
        max_time = 0.040

        update_channel.send(nil)
        slept_last = false

        # sleep 5.seconds
        # UPDATEj
        Loop.new(:update) do
          x_speed_mult = (x_amount * Renderer.render_book.sheet_frame.tile_width).to_f
          y_speed_mult = (y_amount * Renderer.render_book.sheet_frame.tile_height).to_f
          slept = false
          if (delay = Time.monotonic.total_seconds - frame_checker) > max_time
            # Log.warn { "FRAME DELAY: #{delay} - slept: #{slept_last}" }
          end
          frame_checker = Time.monotonic.total_seconds
          # total_frames += 1
          # Renderer.lock_mutex.synchronize do
          #   while Renderer.render_lock
          #     slept = true
          #     sleep 1.millisecond
          #   end

          #   Renderer.render_lock = true
          # end
          unless started
            Log.debug { " - - Started Update loop" }
            started = true
          end

          current = Time.monotonic.total_seconds
          sleep_amount = ((1/FPS) - (current - last_frame)) # .round(6) # - 50.microseconds.total_seconds
          if sleep_amount.positive?
            # Log.debug { "Sleep - #{sleep_amount}" }
            usleep(sleep_amount)
            slept = true
          end
          # while (total_frames / (Time.monotonic.total_seconds - start_time)) > FPS
          #   Fiber.yield
          # end
          update_channel.receive

          player_block, m_time = mutex.synchronize do
            {Player.block, self.moved_time}
          end

          center_block = Renderer.render_book.center_block_for(player_block)
          # Log.debug { "Print from center: #{center_block}, real: #{center_block.real}" }
          # Log.debug { "Player Center: #{Player.block} real: #{Player.block.real}" }

          until Renderer.render_book.sheet_exists?(center_block)
            Log.warn { "WARNING -- CENTER BLOCK DOES NOT EXIST #{center_block.real}" }
            usleep 10.milliseconds
            slept = true
          end
          sheet = Renderer.render_book.sheet(center_block)

          # mutex.synchronize do
          # while (delta = Time.monotonic.total_seconds) - last_frame < (1/FPS)
          #   Fiber.yield
          # end
          current = Time.monotonic.total_seconds
          (time = current - m_time)
          # if time > (Renderer.render_book.sheet_frame.tile_width/speed)
          #   # self.minus_x = 0_i16
          #   self.minus_x = 0.0
          #   self.minus_y = 0.0
          # end
          # self.minus_x = 0 if minus_x < 1 && minus_x > -1
          # self.minus_y = 0 if minus_y < 1 && minus_y > -1
          # self.minus_x = (x_speed_mult - x_amount*(speed*time)) unless minus_x == 0
          # self.minus_y = (y_speed_mult - y_amount*(speed*time)) unless minus_y == 0
          # Player.updated = false

          unless minus_x == 0 && minus_y == 0
            if (prev_x - minus_x >= 3 && prev_x - minus_x < 20) || (prev_y - minus_y >= 3 && prev_y - minus_y < 20)
              Log.warn { "SKIP: #{delay} prev x,y: #{prev_x},#{prev_y} - cur x,y: #{minus_x}, #{minus_y} slept: #{slept}" }
            elsif prev_x == minus_x && prev_y == minus_y
              # Log.error { "Sleep amount: #{sleep_amount} Diff: #{(1/FPS)} - #{(current - last_frame)} - Nonslept frame skipped. delay: #{delay}" } unless slept
              slept_last = slept
              next
            end
          end
          last_frame = current
          # end
          prev_x = minus_x
          prev_y = minus_y
          # Log.debug { "#{minus_x}, #{minus_y}" }

          view_rect, clip_rect = sheet.rects_from(player_block, minus_x.round.to_i16, minus_y.round.to_i16)

          # update_channel.receive
          # Renderer.clear_channel.send(nil)
          # update_channel.receive
          # puts "View: #{view_rect}, Clip: #{clip_rect}"
          Renderer.render_channel.send([
            {view_rect, sheet.sheet, clip_rect},
            {Renderer.player_rect, Renderer.player_texture, nil},
          ])
          self.minus_x = 0 if minus_x < 1.0 && minus_x > -1.0
          self.minus_y = 0 if minus_y < 1.0 && minus_y > -1.0

          if minus_x != 0 && minus_y != 0
            self.minus_x -= (x_amount*speed/FPS)*BOTH_XY_MOVE
            self.minus_y -= (y_amount*speed/FPS)*BOTH_XY_MOVE
          else
            self.minus_x -= (x_amount*speed/FPS) unless minus_x == 0
            self.minus_y -= (y_amount*speed/FPS) unless minus_y == 0
          end

          count += 1
          time = Time.monotonic.total_seconds
          if (time - start_time) >= 1.0
            # puts count
            count = 0
            start_time = time
          end
          # while (count / (Time.monotonic.total_seconds - start_time)) >= FPS
          #   sleep 3.millisecond
          # end
          slept_last = slept
        end

        spawn do
          exit_channel.receive
          SheetMaker.cleanup
          cleanup_channel.send(nil)
        end
      end
    end
  end
end
