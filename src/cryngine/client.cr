require "./listener"
require "./client/response"

module Cryngine
  class Client < Listener
    macro commands(commands)
#, commands_enum, execute)
      ->(request : Cryngine::Client::Response) do
        # unless request.message.includes?('#')
        #   raise ArgumentError.new("Requests must start with a Command ID")
        # end
        # command, remaining = request.message.split('#')
        # command = { {commands_enum}}.new(request.message.command)
        # Log.info { "From #{request.address}: Command #{command}" }

        case request.message.c
        {% for command in commands %}
          when Commands::List::{{command}}.value
            data = {{command}}::Data.from_msgpack request.message.d
            Log.info { "Data Received: #{data.inspect}" }
            controller = {{command}}.new(request)
            controller.call(data)
        {% end %}
        else
          raise "Unknown command #{request.message.c}"
        end
      end
    end

    def listen(proc)
      Log.info { "Connecting to #{@host}:#{@port} with #{@socket.class}" }
      @socket.connect(@host, @port)

      spawn do
        super() do |message, address|
          proc.call Response.new(self, message)
        end
      end
      Fiber.yield
    end

    def send(command : Enum, data)
      @socket.send({c: command.value.to_u8, d: data.to_msgpack}.to_msgpack)
    end

    def handle_error(error)
      raise error
    end
  end
end
