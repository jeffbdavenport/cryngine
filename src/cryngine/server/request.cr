require "../msgp/message"
require "../listener"
require "json"

module Cryngine
  class Server < Listener
    class Request
      getter message : Cryngine::MSGP::Message

      def initialize(@server : Server, @message : Cryngine::MSGP::Message, @address : Socket::Address)
        @responded = false
      end

      def socket_address
        @address
      end

      def address : String
        @address.to_s.split(':').first
      end

      def port : Int32
        @address.to_s.split(':').last.to_i
      end

      def send(command : Enum, data)
        # unless @responded
        @responded = true if @server.send({c: command.value.to_u8, d: data.to_msgpack}.to_msgpack, @address)
        # end
      end

      def responded?
        @responded
      end

      # Sets the sender to be authorized
      def authorized!
        true
      end

      def authorized?
        true
      end
    end
  end
end
