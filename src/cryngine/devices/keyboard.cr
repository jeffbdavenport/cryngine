require "cryngine/display/xmodule"
require "cryngine/system/loop"

module Cryngine
  module Devices
    module Keyboard
      extend self
      alias X11 = Display::XModule
      alias X = X11::X
      LEFT      = X11::XK_Left
      RIGHT     = X11::XK_Right
      UP        = X11::XK_Up
      DOWN      = X11::XK_Down
      KEY_DELAY = 200
      @@updated : Int64 = Time.local.to_unix_ms
      class_getter opposites = {LEFT => RIGHT, RIGHT => LEFT, UP => DOWN, DOWN => UP}
      class_getter key = {LEFT => false, RIGHT => false, UP => false, DOWN => false} of Int32 | UInt64 => Bool
      class_getter key_pressed = {LEFT => false, RIGHT => false, UP => false, DOWN => false} of Int32 | UInt64 => Bool
      class_getter key_delay : Hash(Int32 | UInt64, Int64) = {UP => @@updated, DOWN => @@updated, LEFT => @@updated, RIGHT => @@updated} of Int32 | UInt64 => Int64
      @@keyboard_buffer_updated : Int64 = Time.local.to_unix_ms
      @@keyboard_buffer : Loop?
      @@keys_down_buffer : Loop?

      def initialize
        X11.initialize
        keyboard_buffer
        keys_down_buffer
      end

      def keyboard_buffer
        @@keyboard_buffer ||= Loop.new(:keyboard_buffer) do
          ktype, kcode = X11.get_key

          type_name = case ktype
                      when X11::KeyPress
                        :key_press
                      when X11::KeyRelease
                        :key_release
                      end
          # Log.debug "#{type_name}, code: #{kcode}"

          case ktype
          when X11::KeyPress
            if @@opposites.has_key?(kcode) && X11.keys_down.has_key?(@@opposites[kcode]) && X11.keys_down[@@opposites[kcode]]
              next
            end
            @@key[kcode] = true
            @@key_pressed[kcode] = true
          end
        end
      end

      def keys_down_buffer
        @@keys_down_buffer ||= Loop.new(:keys_down) do
          down = X11.keys_down[DOWN]
          up = X11.keys_down[UP]
          left = X11.keys_down[LEFT]
          right = X11.keys_down[RIGHT]
          time = Time.local.to_unix_ms
          [{up => UP, down => DOWN}, {left => LEFT, right => RIGHT}].each do |group|
            unless group.keys.first && group.keys.last
              group.each do |key, name|
                if key && (time - @@key_delay[name]) > 0
                  if @@key_pressed[name] == true
                    @@key_pressed[name] = false
                    @@key_delay[name] = Time.local.to_unix_ms + KEY_DELAY
                    next
                  end
                  @@key[name] = true
                  # @@key_delay[name] = time
                end
              end
            end
          end
        end
      end
    end
  end
end
