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

      class_getter event_channel = Channel(Event).new(1)
      class_getter key_down = {:up => false, :down => false, :left => false, :right => false}
      class_getter key_press = {:up => false, :down => false, :left => false, :right => false}

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

          Loop.new(:keyborad) do
            if event = Event.poll
              define_keymap if keymap[:up] == Scancode::E
              event_channel.send(event)
            else
              usleep 500.microseconds
            end
          end

          Loop.new(:keyborad) do
            event = event_channel.receive
            case event.type
            when .keyup?, .keydown?
              event = event.as(Event::Keyboard)
              process_keyboard_event(event)
            else
              process_event(event)
            end
          end
        end
      end

      def self.clear_move_press
        @@key_press = {:up => false, :down => false, :left => false, :right => false}
      end

      def self.define_keymap
        keymap.each do |key, sym|
          keycode = LibSDL.get_key_from_scancode(sym.as(Scancode))
          keymap[key] = keycode unless keycode == Keycode::UNKNOWN
        end
      end

      def self.process_keyboard_event(event)
        if keymap.key_for?(event.sym)
          key = keymap.key_for(event.sym)
          key_down[key] = event.keydown?
          if event.keydown?
            key_press[key] = event.keydown?
          end
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
