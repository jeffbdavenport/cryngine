require "./listener"
require "./client/response"

module Cryngine
  class Client < Listener
    macro commands(commands, commands_enum, execute)
      ->(request : Cryngine::Client::Response) do
        unless request.message.includes?('#')
          raise ArgumentError.new("Requests must start with a Command ID")
        end
        command, remaining = request.message.split('#')
        command = {{commands_enum}}.new(command.to_i)
        Log.info { "From #{request.address}: Command #{command}" }
        case command.value
        {% for command in commands %}
          when "{{command}}"
            data = Commands::{{command}}::Data.from_msgpack request.message.data
            Log.info { "Data Received: #{data.inspect}" }
            controller = Commands::{{command}}.new(request)
            controller.call(data)
        {% end %}
        else
          raise "Unknown command #{request.message.command}"
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

    def send(command : String, data)
      @socket.send({command: command, data: data.to_msgpack}.to_msgpack)
    end

    def handle_error(error)
      raise error
    end
  end
end
