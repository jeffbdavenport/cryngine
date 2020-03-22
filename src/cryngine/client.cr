require "./listener"
require "./client/response"

module Cryngine
  class Client < Listener
    def listen
      Log.info "Connecting to #{@host}:#{@port} with #{@socket.class}"
      @socket.connect(@host, @port)

      super do |message, address|
        yield Response.new(self, message)
      end
    end

    def send(message : Slice(UInt8))
      @socket.send(message)
    end
  end
end
