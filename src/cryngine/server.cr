require "./listener"
require "./server/request"

module Cryngine
  class Server < Listener
    def listen
      System::Log.info "Binding port #{@port} for #{@socket.class} on #{@host}"
      @socket.bind(@host, @port)

      super do |message, address|
        yield Request.new(self, message, address)
      end
    end

    def send(message : Slice(UInt8), address)
      @socket.send(message, address)
    end

    def handle_error(error)
      Log.info error
    end
  end
end
