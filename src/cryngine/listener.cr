require "socket"
require "msgpack"
require "./message_pack"

module Cryngine
  abstract class Listener
    getter host, port, socket
    getter socket = UDPSocket.new

    def initialize(@host : String, @port : Int32)
    end

    macro commands(commands)
      def receive(request)
        case request.message.command
        {% for command in commands %}
          when "{{command}}"
            data = Command::{{command}}::Data.from_msgpack request.message.data
            Log.info "Data Received: #{data.inspect}"
            Command::{{command}}.call(request, data)
        {% end %}
        else
          raise "Unknown command #{request.message.command}"
        end
      end
    end

    def listen
      while !socket.closed?
        message, address = socket.receive(1024)
        message = MSGP::Message.from_msgpack message
        Log.info "From #{address}: Command #{message.command}"
        yield(message, address)
        # authorize(request)
      end
      Log.error "#{self.class} closed!"
    end

    private def authorize(request)
      @receiver.authorize(request) unless request.authorized?
      if request.authorized?
        request_receives(request)
      else
        @receiver.authorization_failed(request)
      end
    end

    def authorization_failed(request)
      request.send({code: 401})
    end

    def authorize(request)
      request.authorized!
    end
  end
end
