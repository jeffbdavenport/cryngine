module Cryngine
  # For the base class of controllers for communication
  class Command
    getter data, connection

    def initialize(@connection : RequestType)
    end

    def send(command : String, data)
      @connection.send(command, data)
    end
  end
end
