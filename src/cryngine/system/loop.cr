require "cryngine/display/terminal/terminal"

module Cryngine
  alias Loop = System::Loop

  module System
    class Loop
      include Display
      class_property per_second = true
      class_getter update_channel = Channel(String).new
      class_getter loops = 0
      getter channel : Channel(String)?
      class_property buffer = {} of String => String
      @index = 0
      class_property display_loop_counts = false

      def self.counts
        @@display_loop_counts = true
        spawn do
          loop do
            print "#{buffer.values.join}#{Terminal.reset_cursor}"
            sleep 100.milliseconds
          end
        end
      end

      def initialize(channel : Symbol | String | Nil = nil, wait : Bool = true, same_thread = false, &block)
        @channel = Channel(String).new unless channel.nil?
        @@loops += 1
        @index = @@loops
        if same_thread
          spawn same_thread: true do
            self.class.game_loop(channel, @index, wait, &block)
          end
        else
          spawn do
            self.class.game_loop(channel, @index, wait, &block)
          end
        end
      end

      # per_second : Displays loop iterations each second
      # wait : True if the loop should yield to other fibers
      def self.game_loop(channel : Symbol | String, index : Int32, wait : Bool = true, &block)
        per_second = @@per_second
        display_loop_counts = @@display_loop_counts
        iterator = 0
        update_status = "#{channel}#{" " * (45 - channel.to_s.size)}"
        last_print_time = Time.monotonic

        if display_loop_counts
          buffer[channel.to_s] = "#{Terminal.reset_cursor(Terminal.rows - index)}#{update_status}#{iterator}#{" " * 100}"
        end
        loop do
          print_elapsed = Time.monotonic - last_print_time
          # Make sure window has been resized before showing loop_counts
          if display_loop_counts && (!per_second || (print_elapsed.to_i > 1))
            last_print_time = Time.monotonic
            buffer[channel.to_s] = "#{Terminal.reset_cursor(Terminal.rows - index)}#{update_status}#{iterator}#{" " * 100}"
            iterator = 0 if per_second
          end
          block.call
          # Only set wait to false if you will be customizing where the block yields
          Fiber.yield if wait
          # sleep 10.second
          iterator += 1
        end
      end
    end
  end
end
