require "sdl"

module Cryngine
  module Event
    include SDL

    def self.initialize
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
      spawn do
        loop do
          while e = Event.poll
            case e
            when SDL::Event::Quit
              exit
            end
          end
          sleep 80.milliseconds
        end
      end
    end
  end
end
