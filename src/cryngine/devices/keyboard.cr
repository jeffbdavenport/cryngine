# require "cryngine/system/loop"
require "sdl"

module Cryngine
  module Devices
    module Keyboard
      include SDL
      alias Window = Display::Window
      alias Scancode = LibSDL::Scancode
      alias Keycode = LibSDL::Keycode
      alias EventType = LibSDL::EventType

      class_getter event_channel = Channel(LibSDL::Event).new(10000)
      class_getter key_down = {:up => false, :down => false, :left => false, :right => false}
      class_getter key_press = {:up => false, :down => false, :left => false, :right => false}
      class_getter key_watch = {} of Keycode => Bool
      @@keys_down = Time.monotonic
      class_getter mutex = Mutex.new

      class_getter keymap : Hash(Symbol, Keycode | Scancode) = {
        :up    => Scancode::E,
        :down  => Scancode::D,
        :left  => Scancode::S,
        :right => Scancode::F,
      } of Symbol => Keycode | Scancode

      def self.initialize
        spawn do
          Event.ignore EventType::TEXT_INPUT
          Event.ignore EventType::TEXT_EDITING
          Event.ignore EventType::FIRSTEVENT
          LibSDL.event_state(LibSDL::EventType::MOUSE_MOTION, LibSDL::IGNORE)
          LibSDL.event_state(LibSDL::EventType::WINDOW_EVENT, LibSDL::IGNORE)
          # LibSDL.event_state(LibSDL::EventType::KEYDOWN, LibSDL::IGNORE)
          # LibSDL.event_state(LibSDL::EventType::KEYUP, LibSDL::IGNORE)
          LibSDL.event_state(LibSDL::EventType::TEXT_EDITING, LibSDL::IGNORE)
          LibSDL.event_state(LibSDL::EventType::TEXT_INPUT, LibSDL::IGNORE)
          LibSDL.event_state(LibSDL::EventType::MOUSE_BUTTON_UP, LibSDL::IGNORE)
          LibSDL.event_state(LibSDL::EventType::MOUSE_BUTTON_DOWN, LibSDL::IGNORE)
          LibSDL.event_state(LibSDL::EventType::MOUSE_WHEEL, LibSDL::IGNORE)
          LibSDL.event_state(LibSDL::EventType::USER_EVENT, LibSDL::IGNORE)
          LibSDL.event_state(LibSDL::EventType::SYS_WM_EVENT, LibSDL::IGNORE)

          Loop.new(:keyborad) do
            if event = Event.poll
              now = Time.monotonic
              define_keymap if keymap[:up] == Scancode::E
              case event.type
              when .keyup?, .keydown?
                event = event.as(Event::Keyboard)
                process_keyboard_event(event, now)
              else
                process_event(event)
              end
            else
              sleep 20.millisecond
            end
          end
        end
      end

      def self.clear_downs
        key_down[:left] = false
        key_down[:right] = false
        key_down[:up] = false
        key_down[:down] = false
      end

      def self.clear_x_press
        key_press[:left] = false
        key_press[:right] = false
      end

      def self.clear_y_press
        key_press[:up] = false
        key_press[:down] = false
      end

      def self.define_keymap
        keymap.each do |key, sym|
          keycode = LibSDL.get_key_from_scancode(sym.as(Scancode))
          keymap[key] = keycode unless keycode == Keycode::UNKNOWN
        end
      end

      def self.process_keyboard_event(event, now)
        return if event.repeat == 1 && !event.keyup?

        key = if keymap.key_for?(event.sym)
                keymap.key_for(event.sym)
              else
                nil
              end

        if event.keydown?
          if key_watch.has_key?(event.sym) && key_watch[event.sym] == true
            puts "KEYUP NOT DETECTED FOR: #{key} #{event.sym}. Keywatch: #{key_watch[event.sym]}"
            Log.error { "KEYUP NOT DETECTED FOR: #{key} #{event.sym}. Keywatch: #{key_watch[event.sym]}" }
            Window.exit_channel.send(nil)
          end

          key_watch[event.sym] = true
        else
          if key_watch.has_key?(event.sym) && key_watch[event.sym] == false
            puts "KEYDOWN NOT DETECTED FOR: #{key} #{event.sym}. Keywatch: #{key_watch[event.sym]}"
            Log.error { "KEYDOWN NOT DETECTED FOR: #{key} #{event.sym}. Keywatch: #{key_watch[event.sym]}" }
            Window.exit_channel.send(nil)
          end
          key_watch[event.sym] = false
        end

        if keymap.key_for?(event.sym)
          key = mutex.synchronize do
            keymap.key_for(event.sym)
          end

          Log.debug { "#{key} #{event.type}" }

          mutex.synchronize do
            key_down[key] = !event.keyup?
          end

          if event.keydown?
            # elsif event.keyup?
            mutex.synchronize do
              key_press[key] = event.repeat == 0
            end
          end
        else
          # Log.error { "Error! No key_for Keyboard Event: #{event.to_unsafe.value.key}" }
        end

        case event.sym
        when Keycode::ESCAPE
          Window.exit_channel.send(nil)
        end
      end

      def self.process_event(event)
        case event.type
        when EventType::QUIT, EventType::APP_TERMINATING
          Window.exit_channel.send(nil)
        when EventType::TEXT_INPUT
        else
          puts event.type
        end
      end
    end
  end
end
