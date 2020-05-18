require "./listener"
require "./server/request"

module Cryngine
  class Server < Listener
    macro commands(commands)
      ->(request : Cryngine::Server::Request) do
        case request.message.command
        {% for command in commands %}
          when "{{command}}"
            data = Commands::{{command}}::Data.from_msgpack request.message.data
            Log.info "Data Received: #{data.inspect}"
            controller = Commands::{{command}}.new(request)
            controller.call(data)
        {% end %}
        else
          Log.info "Unknown command #{request.message.command}"
        end
      end
    end

    def listen(proc)
      System::Log.info "Binding port #{@port} for #{@socket.class} on #{@host}"
      @socket.bind(@host, @port)

      spawn do
        super() do |message, address|
          proc.call Request.new(self, message, address)
        end
      end
      Fiber.yield
    end

    def send(command : String, data, address)
      @socket.send({command: command, data: data.to_msgpack}.to_msgpack, address)
    end
  end
end
