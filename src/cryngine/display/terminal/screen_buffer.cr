require "../../system/loop"

module Cryngine
  module Display
    module Terminal
      module ScreenBuffer
        extend self
        class_property buffer_channel = Channel(String).new
        class_property buffer = {} of Symbol => String
        @@ephemeral_buffer = ""
        # How long to wait before printing again
        PRINT_DELAY = 50.milliseconds

        def initialize
          Loop.new(:buffer, false) do
            sleep PRINT_DELAY
            print "#{ephemeral_buffer}#{buffer.values.join}#{Terminal.reset_cursor}"
          end

          Loop.new(:channel) do
            puts buffer_channel.receive
          end
        end

        def puts(string : String)
          @@ephemeral_buffer += string
        end

        def ephemeral_buffer
          buffer = @@ephemeral_buffer
          @@ephemeral_buffer = ""
          buffer
        end
      end
    end
  end
end
