module Cryngine
  module System
    class Loop
      include Display
      class_property display_loop_counts = false
      class_getter update_channel = Channel(String).new
      class_getter loops = 0
      getter channel : Channel(String)?
      @index = 0

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
        iterator.each do |i|
          # Make sure window has been resized before showing loop_counts
          if display_loop_counts && (ScreenBuffer.buffer.has_key?(:update) || channel == :update)
            ScreenBuffer.buffer[channel] = "#{Terminal.reset_cursor(index)}#{update_status}#{i}"
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
