require "cryngine/exceptions"
require "cryngine/client/response"
require "cryngine/server/request"

module Cryngine
  VERSION = "0.1.0"
  alias AnyRequest = Server::Request | Client::Response

  module Display
  end

  module Devices
  end

  module System
  end

  module Commands
  end
end
