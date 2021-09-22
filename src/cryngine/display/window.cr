require "magickwand-crystal"
require "sdl"
require "sdl/lib_img"
require "../map/tile"
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
      BOTH_XY_MOVE = 0.77
      # Seems too slow, but is the exact distance for a circle
      # BOTH_XY_MOVE = 0.7066666666666667

      class_getter update_channel = Channel(Nil).new(2)
      class_getter input_wait = Channel(Nil).new(2)
      class_getter map_checker_channel = Channel(Tuple(Int16, Int16)).new
      class_getter input_mover_channel = Channel(Tuple(Int16, Int16)).new(2)
      class_getter cleanup_channel = Channel(Nil).new
      class_getter exit_channel = Channel(Nil).new
      class_getter mutex = Mutex.new
      class_property minus_x : Float64 = 0.0
      class_property minus_y : Float64 = 0.0
      class_property x_amount : Int16 = 0_i16
      class_property y_amount : Int16 = 0_i16
      class_property x_velocity : Int16 = 0_i16
      class_property y_velocity : Int16 = 0_i16

      # @@mutex = Mutex.new
      class_property moved_time : Float64 = Time.monotonic.total_seconds

      def self.initialize(game_title : String)
        Devices::Keyboard.initialize

        LibIMG.init LibIMG::Init::PNG

        Renderer.initialize(game_title, WIDTH, HEIGHT)

        # (unused, w, h, bd, rmask, gmask, bmask, amask)
        # surface = LibSDL.create_rgb_surface(0, surf_width, surf_height, BIT_DEPTH, 0xff000000, 0x00ff0000, 0x0000ff00, 0)

        if SheetMaker.montage_map
          Loop.new(:map_montage) do
            col, row = map_checker_channel.receive
            puts "Started Map montage"
            next if Renderer.render_book.sheet_exists?(0, 0)

            min_x = (Map.layers.values.map(&.startx).min)
            min_y = (Map.layers.values.map(&.starty).min)

            start_col = SheetMaker.pixel_book.sheet_col min_x
            start_row = SheetMaker.pixel_book.sheet_col min_y
            max_x = (Map.layers.values.map { |value| value.chunks.map(&.x).max * Chunk.width }.max + Chunk.width)
            max_y = (Map.layers.values.map { |value| value.chunks.map(&.y).max * Chunk.height }.max + Chunk.height)
            end_col = SheetMaker.pixel_book.sheet_col max_x
            end_row = SheetMaker.pixel_book.sheet_row max_y

            start_col.upto(end_col).each do |col|
              start_row.upto(end_row).each do |row|
                if SheetMaker.dither
                  SheetMaker.pixel_book_above.start_sheet(col, row)
                  SheetMaker.pixel_book_below.start_sheet(col, row)
                else
                  Renderer.render_book_above.start_sheet(col, row)
                  Renderer.render_book_below.start_sheet(col, row)
                end
                block = SheetMaker.pixel_book.block_for(col, row)
                SheetMaker.sheet_maker_channel.send({col, row, block})
                puts "Started #{col}, #{row}"
              end
            end
          end
        else
          Loop.new(:map_checker, same_thread: true) do
            col, row = map_checker_channel.receive
            # from_col, from_row = map_checker_channel.receive

            # [0, -1, 1].each do |col|
            #   [0, -1, 1].each do |row|
            # col = col.to_i16 + from_col
            # row = row.to_i16 + from_row

            next if Renderer.render_book.sheet_exists?(col, row)
            # Log.debug { "^ Check map start sheet from: #{col}, #{row}" }

            book = if SheetMaker.dither
                     SheetMaker.pixel_book
                   else
                     Renderer.render_book
                   end
            next if book.sheet_started?(col, row)

            if SheetMaker.dither
              SheetMaker.pixel_book_above.start_sheet(col, row)
              SheetMaker.pixel_book_below.start_sheet(col, row)
            else
              Renderer.render_book_above.start_sheet(col, row)
              Renderer.render_book_below.start_sheet(col, row)
            end

            Log.debug { "Started sheet #{col}, #{row}" }

            block = Renderer.render_book.block_for(col, row)

            SheetMaker.sheet_maker_channel.send({col, row, block})
            #   end
            # end
          end
        end

        # Wait for spawns to all initialize here
        update_channel.receive
        map_checker_channel.send({0_i16, 0_i16})

        book = if SheetMaker.dither
                 SheetMaker.pixel_book
               else
                 Renderer.render_book
               end

        until Renderer.render_book_above.sheet_exists?(0, 0) && Renderer.render_book_below.sheet_exists?(0, 0)
          sleep 1.milliseconds
          Renderer.render_sheets_channel_wait.send(nil) if Renderer.render_sheets_channel_wait.waiting?
        end

        speed = SPEED/book.view_scale

        input_frames = 0
        input_mutex = Mutex.new
        x_mutex = Mutex.new
        y_mutex = Mutex.new
        sync = 100.milliseconds.total_seconds

        # self.y
        # INPUT
        input_sleep = 1/FPS
        input_wait.send(nil)
        input_wait.send(nil)
        Loop.new(:input_x) do
          # unless x_velocity == 0
          #   # usleep(sleep_amount)
          #   usleep(input_sleep)
          #   next
          # end
          key_down = Keyboard.mutex.synchronize do
            Keyboard.key_down.dup
          end
          key_press = Keyboard.mutex.synchronize do
            Keyboard.key_press.dup
          end
          # Log.debug { "In X: #{key_down},#{key_press}" }

          input_mutex.synchronize do
            if (key_down[:left] || key_press[:left]) && (key_down[:right] || key_press[:right])
              self.x_amount = 0
            elsif key_down[:left] || key_press[:left]
              self.x_amount = -1
            elsif key_down[:right] || key_press[:right]
              self.x_amount = 1
            else
              self.x_amount = 0
            end
          end
          Keyboard.clear_x_press
          if x_amount == 0
            sleep(input_sleep)
            next
          end
          sleep_amount = if y_velocity != 0
                           (Renderer.render_book.sheet_frame.tile_width/BOTH_XY_MOVE)/speed
                         else
                           Renderer.render_book.sheet_frame.tile_width/speed
                         end
          # puts "before Moving player"
          input_mover_channel.send({x_amount, 0_i16})
          # puts "Moving player"
          # Map::Player.move(Renderer.render_book, x_amount, 0)
          # self.moved_time = Time.monotonic.total_seconds
          # self.minus_x = (x_amount * Renderer.render_book.sheet_frame.tile_width).to_f

          # puts " This is in the input_move loop.#{x_amount}, #{y_amount}  #{self.minus_x}, #{self.minus_y}"

          # self.x_velocity = x_amount
          sleep(sleep_amount)
        end

        Loop.new(:input_y) do
          # unless y_velocity == 0
          #   # usleep(sleep_amount)
          #   sleep(input_sleep)
          #   next
          # end
          key_down = Keyboard.mutex.synchronize do
            Keyboard.key_down.dup
          end
          key_press = Keyboard.mutex.synchronize do
            Keyboard.key_press.dup
          end
          # Log.debug { "In Y: #{key_down},#{key_press}" }
          input_mutex.synchronize do
            if (key_down[:up] || key_press[:up]) && (key_down[:down] || key_press[:down])
              self.y_amount = 0
            elsif key_down[:up] || key_press[:up]
              self.y_amount = -1
            elsif key_down[:down] || key_press[:down]
              self.y_amount = 1
            else
              self.y_amount = 0
            end
          end
          Keyboard.clear_y_press
          if y_amount == 0
            sleep(input_sleep)
            next
          end
          sleep_amount = if x_velocity != 0
                           (Renderer.render_book.sheet_frame.tile_width/BOTH_XY_MOVE)/speed
                         else
                           Renderer.render_book.sheet_frame.tile_width/speed
                         end

          # if (key_down[:up] || key_down[:down]) && (key_down[:left] || key_press[:left])
          # end
          # puts "before Moving player"
          input_mover_channel.send({0_i16, y_amount})
          # puts "Moving player"
          # Map::Player.move(Renderer.render_book, 0, y_amount)

          # puts " This is in the input_move loop.#{x_amount}, #{y_amount}  #{self.minus_x}, #{self.minus_y}"

          # self.y_velocity = y_amount
          # TODO : Sleep longer if moving both direcitons
          sleep(sleep_amount)
        end

        Loop.new(:input_mover) do
          x, y = input_mover_channel.receive
          # sleep 60.milliseconds
          # x2, y2 = input_mover_channel.receive unless input_mover_channel.empty?

          # x = x2 if x2 && x == 0
          # y = y2 if y2 && y == 0
          Map::Player.move(Renderer.render_book, x, y)
          self.moved_time = Time.monotonic.total_seconds
          self.x_velocity = x unless x == 0
          self.y_velocity = y unless y == 0
          self.minus_x += (x * Renderer.render_book.sheet_frame.tile_width).to_f unless x == 0
          self.minus_y += (y * Renderer.render_book.sheet_frame.tile_height).to_f unless y == 0

          # sleep_amount = if x != 0 && y != 0
          #                  (Renderer.render_book.sheet_frame.tile_width/BOTH_XY_MOVE)/speed
          #                else
          #                  Renderer.render_book.sheet_frame.tile_width/speed
          #                end
        end

        started = false
        count = 0
        start_time = Time.monotonic.total_seconds
        delta = Time.monotonic.total_seconds
        last_print_time = Time.monotonic.total_seconds

        last_frame = Time.monotonic.total_seconds
        prev_x = -1.0
        prev_y = -1.0
        total_frames = 0

        frame_checker = Time.monotonic.total_seconds
        max_time = 0.040

        update_channel.send(nil)
        slept_last = false

        # UPDATE
        Loop.new(:update) do
          x_speed_mult = (x_velocity * Renderer.render_book.sheet_frame.tile_width).to_f
          y_speed_mult = (y_velocity * Renderer.render_book.sheet_frame.tile_height).to_f

          current = Time.monotonic.total_seconds
          sleep_amount = ((1/FPS) - (current - last_frame))
          if sleep_amount.positive?
            # Log.debug { "Sleep - #{sleep_amount}" }
            usleep(sleep_amount)
            slept = true
          end
          Log.debug { "Did not sleep" } unless slept

          update_channel.receive

          player_block, m_time = mutex.synchronize do
            {Player.block, self.moved_time}
          end

          # center_block = Renderer.render_book.center_block_for(player_block)

          # until Renderer.render_book.sheet_exists?(center_block)
          #   Log.warn { "WARNING -- CENTER BLOCK DOES NOT EXIST #{center_block.real} #{Renderer.render_book.sheet_for(center_block)}" }
          #   while Renderer.render_sheets_channel_wait.waiting?
          #     Renderer.render_sheets_channel_wait.send(nil)
          #   end
          #   map_checker_channel.send(Renderer.render_book.sheet_for(center_block))
          #   usleep 100.milliseconds
          #   slept = true
          # end

          # self.minus_x = (x_speed_mult - x_velocity*(speed*time)) unless minus_x == 0
          # self.minus_y = (y_speed_mult - y_velocity*(speed*time)) unless minus_y == 0

          printables = [] of Tuple(Rect, SDL::Texture, Rect?)

          # current = Time.monotonic.total_seconds
          # (time = current - m_time)
          last_frame = Time.monotonic.total_seconds

          if minus_x == 0 && minus_y == 0 && x_velocity == 0 && y_velocity == 0
            Renderer.render_channel.send(printables)
            next
          end

          prev_x = minus_x
          prev_y = minus_y

          sheet = Renderer.render_book_below.sheet(0, 0)
          view_rect, clip_rect = sheet.rects_from(player_block, minus_x.round.to_i16, minus_y.round.to_i16)
          printables.push({view_rect, sheet.sheet, clip_rect})

          printables.push({Renderer.player_rect, Renderer.loaded_player_texture, nil})

          sheet = Renderer.render_book_above.sheet(0, 0)
          view_rect, clip_rect = sheet.rects_from(player_block, minus_x.round.to_i16, minus_y.round.to_i16)
          printables.push({view_rect, sheet.sheet, clip_rect})

          # sheet = Renderer.collision_render_book.sheet(0, 0)
          # view_rect, clip_rect = sheet.rects_from(player_block, minus_x.round.to_i16, minus_y.round.to_i16)
          # printables.push({view_rect, sheet.sheet, clip_rect})

          Renderer.render_channel.send(printables)
          input_mutex.synchronize do
            # We had finished our move

            self.x_velocity = 0 if minus_x == 0
            self.y_velocity = 0 if minus_y == 0
            next if minus_x == 0 && minus_y == 0

            if x_velocity != 0 && y_velocity != 0
              # self.minus_x = ((x_speed_mult/BOTH_XY_MOVE) - x_velocity*(speed*time))
              # self.minus_y = ((y_speed_mult/BOTH_XY_MOVE) - y_velocity*(speed*time))
              self.minus_x -= (x_velocity*speed/FPS)*BOTH_XY_MOVE
              self.minus_y -= (y_velocity*speed/FPS)*BOTH_XY_MOVE
            else
              # self.minus_x = (x_speed_mult - x_velocity*(speed*time)) unless minus_x == 0
              # self.minus_y = (y_speed_mult - y_velocity*(speed*time)) unless minus_y == 0
              self.minus_x -= (x_velocity*speed/FPS) unless minus_x == 0
              self.minus_y -= (y_velocity*speed/FPS) unless minus_y == 0
            end
            self.minus_x = 0 if minus_x < 0 && x_velocity > 0
            self.minus_y = 0 if minus_y < 0 && y_velocity > 0
            self.minus_x = 0 if minus_x > 0 && x_velocity < 0
            self.minus_y = 0 if minus_y > 0 && y_velocity < 0
          end
        end

        spawn same_thread: true do
          exit_channel.receive
          SheetMaker.cleanup
          cleanup_channel.send(nil)
        end
      end
    end
  end
end
