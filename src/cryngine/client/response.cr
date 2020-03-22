require "../listener"

module Cryngine
  class Client < Listener
    class Response
      getter message

      def initialize(@client : Client, @message : MSGP::Message)
      end

      def send(message)
        @client.send(message)
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
