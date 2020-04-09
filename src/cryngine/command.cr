require "cryngine/client/response"
require "cryngine/server/request"

module Cryngine
  # For the base class of controllers for communication
  class Command
    getter data, connection

    def initialize(@connection : Server::Request)
    end

    def send(command : String, data)
      @connection.send(command, data)
    end
  end

  class ClientCommand
    getter data, connection

    def initialize(@connection : Client::Response)
    end

    def send(command : String, data)
      @connection.send(command, data)
    end
  end
end
