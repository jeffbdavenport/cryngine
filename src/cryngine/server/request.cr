require "../listener"
require "json"

module Cryngine
  class Server < Listener
    class Request
      getter message : String

      def initialize(@server : Server, @message : String, @address : Socket::Address)
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

      def send(data)
        # unless @responded
        @responded = true if @server.send(data, @address)
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
