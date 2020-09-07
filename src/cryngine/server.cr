require "./listener"
require "./server/request"

module Cryngine
  class Server < Listener
    macro commands(commands, commands_enum, execute)
      ->(request : Cryngine::Server::Request) do
        command, remaining = request.message.split('#')
        command = {{commands_enum}}.new(command.to_i)
        Log.info { "From #{request.address}: Command #{command}" }
        case command.value
        {% for command in commands %}
          when {{commands_enum}}::{{command}}.value
            model, data = {{execute}}.parse_data remaining
            if model.nil? || data.nil?
              Log.error { "Model is nil" }
              return
            end
            Log.info { "Data Received: #{data.inspect}" }
            controller = {{execute}}::{{command}}.new(request)
            controller.call(model, data)
        {% end %}
        end
      end
    end

    def listen(proc)
      Log.info { "Binding port #{@port} for #{@socket.class} on #{@host}" }
      @socket.bind(@host, @port)

      spawn do
        super() do |message, address|
          proc.call Request.new(self, message, address)
        end
      end
      Fiber.yield
    end

    def send(data, address)
      @socket.send(data, address)
    end

    def convert_int(int)
      bytes = nil
      case int
      when Int64
        bytes = Bytes[2, 0, 1, 0, int.bits(0..7), int.bits(8..15), int.bits(16..23), int.bits(24..31), int.bits(32..39), int.bits(40..47), int.bits(48..55), int.bits(56..63)]
      else
        bytes = Bytes[2, 0, 0, 0, int.bits(0..7), int.bits(8..15), int.bits(16..23), int.bits(24..31)]
      end
      puts bytes.to_s
      bytes
    end

    def handle_error(error)
      Log.info { error }
    end
  end
end
