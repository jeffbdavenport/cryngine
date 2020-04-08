require "./listener"
require "./server/request"

module Cryngine
  alias RequestType = Server::Request

  class Server < Listener
    def listen
      System::Log.info "Binding port #{@port} for #{@socket.class} on #{@host}"
      @socket.bind(@host, @port)

      super do |message, address|
        yield Request.new(self, message, address)
      end
    end

    def send(command : String, data, address)
      @socket.send({command: command, data: data.to_msgpack}.to_msgpack, address)
    end

    def handle_error(error)
      Log.info error
    end
  end
end
