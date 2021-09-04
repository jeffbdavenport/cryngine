require "cryngine/display/terminal/screen_buffer"
require "cryngine/display/terminal/terminal"

module Cryngine
  alias Loop = System::Loop

  module System
    class Loop
      include Display
      class_property display_loop_counts = false
      class_getter update_channel = Channel(String).new
      class_getter loops = 0
      getter channel : Channel(String)?
      @index = 0
      class_property start_time = Time.monotonic

      def initialize(channel : Symbol? = nil, wait : Bool = true, count = nil, &block)
        @channel = Channel(String).new unless channel.nil?
        @@loops += 1
        @index = @@loops
        spawn do
          self.class.game_loop(channel, @index, count, wait, &block)
        end
      end

      def self.game_loop(channel : Symbol, index : Int32, count = nil, wait : Bool = true, &block)
        iterator = if count.nil?
                     1.step
                   else
                     count.times
                   end
        update_status = "#{channel}#{" " * (25 - channel.to_s.size)}"
        last_print_time = Time.monotonic

        iterator.each do |i|
          elapsed_seconds = (Time.monotonic - start_time)
          print_elapsed = Time.monotonic - last_print_time
          # Make sure window has been resized before showing loop_counts
          if display_loop_counts && (print_elapsed.to_i > 1) # && (Terminal::ScreenBuffer.buffer.has_key?(:update) || channel == :update)
            last_print_time = Time.monotonic
            Terminal::ScreenBuffer.buffer[channel] = "#{Terminal.reset_cursor(index - 7)}#{update_status}#{(i / elapsed_seconds.to_i).to_i}"
          end
          block.call
          # Only set wait to false if you will be customizing where the block yields
          Fiber.yield if wait
        end
      end

      def self.update_loop(count = nil, wait : Bool = true, &block)
        @@loops += 1
        Display::Window.resize_terminal
        game_loop(:update, loops, count, wait, &block)
      end
    end
  end
end
