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
              x_amount = (Player.unscaled_col * 2) * col
              y_amount = (Player.unscaled_row * 2) * row
              real_x = (Renderer.render_book.offset_x + x_amount).to_i64
              real_y = (Renderer.render_book.offset_y + y_amount).to_i64

              Log.debug { "Check map start block: #{real_x}, #{real_y}" }

              block = Map::Block.from_real real_x, real_y

              Renderer.sheet_maker_channel.send({col, row, block})
            end
          end
        end

        update_channel.receive
        map_checker_channel.send(nil)

        until Renderer.render_book.finished?
          sleep 100.milliseconds
        end

        # Map::Player.move(26, 20)
        # Map::Player.move(-25, -14)

        Loop.new(:update) do
          Renderer.render_book.cols.times do |col|
            Renderer.render_book.rows.times do |row|
              # next unless col == 1 && row == 1
              sheet = Renderer.render_book.sheet(col, row)
              sheet_frame = sheet.book.sheet_frame

              view_rect, clip_rect = sheet.rects_from(Player.block)

              # puts "Send to :render_channel"
              Renderer.render_channel.send({view_rect, sheet.sheet, clip_rect})
            end
          end

          # puts "Send player to :render_channel"
          Renderer.render_channel.send({Renderer.player_rect, Renderer.player_texture, nil})

          Renderer.present_channel.send(nil)
          # puts "Main present"
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
