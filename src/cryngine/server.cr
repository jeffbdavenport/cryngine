require "./listener"
require "./server/request"

module Cryngine
  class Server < Listener
    LISTEN_WORKERS = 4

    macro commands_string(commands, commands_enum, execute)
      ->(request : Cryngine::Server::RequestString) do
        unless request.message.includes?('#')
          raise ArgumentError.new("Requests must start with a Command ID")
        end
        command, remaining = request.message.split('#')
        command = {{commands_enum}}.new(command.to_i)
        Log.info { "From #{request.address}: Command #{command}" }
        case command.value
        {% for command in commands %}
          when {{commands_enum}}::{{command}}.value

            controller = {{execute}}::{{command}}.new(request)
            begin
                model, data = {{execute}}.parse_data remaining
                if model.nil? || data.nil?
                  Log.error { "Model is nil" }
                  return
                end
              Log.info { "Data Received: #{data.inspect}" }
              controller.call(model, data)
            rescue error
              Log.error { "#{error}\n#{error.backtrace.join("\n")}" }
              if controller
                controller.send(false)
              end
            end
        {% end %}
        end
      end
    end

    macro commands(commands, commands_enum, execute)
      ->(request : Cryngine::Server::Request) do
        case request.message.c
        {% for command in commands %}
          when {{commands_enum}}::{{command}}.value
            data = Commands::{{command}}::Data.from_msgpack request.message.d

              Log.info { "Data Received: #{data.inspect}" }
              controller = Commands::{{command}}.new(request)
              controller.call(data)
        {% end %}
        end
      end
    end

    def listen_string(proc, proc2)
      Log.info { "Binding port #{@port} for #{@socket.class} on #{@host}" }
      @socket.bind(@host, @port)
      LISTEN_WORKERS.times do
        spawn do
          super() do |message, address|
            proc.call RequestString.new(self, message, address)
          end
        end
      end
      loop do
        proc2.call
        sleep 300
      end
    end

    def listen(proc)
      Log.info { "Binding port #{@port} for #{@socket.class} on #{@host}" }
      @socket.bind(@host, @port)
      LISTEN_WORKERS.times do
        spawn do
          super() do |message, address|
            proc.call Request.new(self, message, address)
          end
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
