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

module Cryngine
  module Display
    module Window
      class_property window : SDL::Window
      class_getter sheet : Map::Sheet
      @@window = uninitialized SDL::Window
      @@sheet = uninitialized Map::Sheet
      WIDTH     = 1680
      HEIGHT    =  880
      BIT_DEPTH =   24

      class_getter update_channel = Channel(Nil).new
      class_getter map_checker_channel = Channel(Nil).new
      class_getter cleanup_channel = Channel(Nil).new
      class_getter exit_channel = Channel(Nil).new
      class_getter mutex : Mutex
      @@mutex = Mutex.new

      def self.initialize(game_title : String)
        Cryngine::Event.initialize
        Devices::Keyboard.initialize

        LibIMG.init LibIMG::Init::PNG

        Renderer.initialize(game_title, WIDTH, HEIGHT)

        # (unused, w, h, bd, rmask, gmask, bmask, amask)
        # surface = LibSDL.create_rgb_surface(0, surf_width, surf_height, BIT_DEPTH, 0xff000000, 0x00ff0000, 0x0000ff00, 0)

        Loop.new(:map_checker) do
          map_checker_channel.receive

          [0, -1, 1].each do |col|
            [0, -1, 1].each do |row|
              col = col.to_i16
              row = row.to_i16
              # x_amount = (Player.unscaled_col * 2) * col
              # y_amount = (Player.unscaled_row * 2) * row
              frame = Renderer.render_book.half_sheet_frame
              x_amount = (frame.cols - (Window.window.width / frame.tile_width / 2.0)).floor
              y_amount = (frame.rows - (Window.window.height / frame.tile_height / 2.0)).floor
              # puts "x,y #{x_amount} #{y_amount}: cols,rows #{frame.cols}, #{frame.rows} tile: #{frame.tile_width}"
              real_x = (Renderer.render_book.offset_x + x_amount * col).to_i64
              real_y = (Renderer.render_book.offset_y + y_amount * row).to_i64

              # Log.debug { "Check map start block: #{real_x}, #{real_y}" }

              block = Map::Block.from_real real_x, real_y

              SheetMaker.sheet_maker_channel.send({col + 1, row + 1, block})
            end
          end
        end

        # Loop.new(:map_checker) do
        #   map_checker_channel.receive

        #   [1, 0, 2].each do |col|
        #     [1, 0, 2].each do |row|
        #       col = col.to_i16
        #       row = row.to_i16
        #       # x_amount = (Player.unscaled_col * 2) * col
        #       # y_amount = (Player.unscaled_row * 2) * row
        #       # frame = Renderer.render_book.half_sheet_frame
        #       # x_amount = (frame.cols - (Window.window.width / frame.tile_width / 2.0)).floor
        #       # y_amount = (frame.rows - (Window.window.height / frame.tile_height / 2.0)).floor
        #       # # puts "x,y #{x_amount} #{y_amount}: cols,rows #{frame.cols}, #{frame.rows} tile: #{frame.tile_width}"
        #       # real_x = (Renderer.render_book.offset_x + x_amount * col).to_i64
        #       # real_y = (Renderer.render_book.offset_y + y_amount * row).to_i64

        #       # # Log.debug { "Check map start block: #{real_x}, #{real_y}" }

        #       # block = Map::Block.from_real real_x, real_y
        #       block = Renderer.render_book.block_for(col, row)

        #       SheetMaker.sheet_maker_channel.send({col, row, block})
        #     end
        #   end
        # end

        update_channel.receive
        map_checker_channel.send(nil)

        book = if SheetMaker.dither
                 SheetMaker.pixel_book
               else
                 Renderer.render_book
               end

        until Renderer.render_book.sheet_exists?(1, 1) && (!SheetMaker.dither || SheetMaker.pixel_book.finished?)
          # sleep 5.milliseconds
          Fiber.yield
        end

        # Map::Player.move(26, 20)
        # Map::Player.move(-25, -14)

        Loop.new(:input) do
          sleep 400.milliseconds
          Map::Player.move(1, 1)
        end

        started = false
        Loop.new(:update) do
          Renderer.lock_mutex.synchronize do
            while Renderer.render_lock
              Fiber.yield
            end

            Renderer.render_lock = true
          end
          unless started
            Log.debug { " - - Started Update loop" }
            started = true
          end
          sheet = Renderer.render_book.sheet(1, 1)

          view_rect, clip_rect = sheet.rects_from(Player.block)

          # Renderer.render_book.cols.times do |col|
          #   Renderer.render_book.rows.times do |row|
          #     next unless col == 1 && row == 1

          # puts "View: #{view_rect}, Clip: #{clip_rect}"
          # puts "Send to :render_channel"
          Renderer.render_channel.send({view_rect, sheet.sheet, clip_rect})
          #   end
          # end

          # puts "Send player to :render_channel"
          Renderer.render_channel.send({Renderer.player_rect, Renderer.player_texture, nil})

          Renderer.present_channel.send(nil)
          update_channel.receive

          sleep(1 / 60.0)
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
