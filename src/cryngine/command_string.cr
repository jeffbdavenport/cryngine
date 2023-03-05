require "cryngine/client/response"
require "cryngine/server/request_string"

module Cryngine
  # For the base class of controllers for communication
  class CommandString
    enum Result
      Success
      Failed
    end

    getter data, connection

    def initialize(@connection : Server::RequestString)
    end

    def send(enum_value : Enum)
      @connection.send(enum_value.value.to_i.to_s)
    end

    def send(bool : Bool)
      if bool
        send = Result::Success
      else
        send = Result::Failed
      end
      @connection.send(send.value.to_i.to_s)
    end

    def send(data : String)
      @connection.send(data)
    end
  end

  class ClientCommand
    getter data, connection

    def initialize(@connection : Client::Response)
    end

    def send(data)
      @connection.send(data)
    end
  end
end
