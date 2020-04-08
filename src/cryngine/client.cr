require "./listener"
require "./client/response"

module Cryngine
  alias RequestType = Client::Response

  class Client < Listener
    def listen
      Log.info "Connecting to #{@host}:#{@port} with #{@socket.class}"
      @socket.connect(@host, @port)

      super do |message, address|
        yield Response.new(self, message)
      end
    end

    def send(command : String, data)
      @socket.send({command: command, data: data.to_msgpack}.to_msgpack)
    end

    def handle_error(error)
      raise error
    end
  end
end
