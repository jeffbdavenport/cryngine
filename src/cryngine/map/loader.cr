require "../map"

module Cryngine
  module Map
    module Loader
      def self.initialize(name)
        load_map(name)
      end

      def self.load_map(name : String)
        @@current_map = Map.new(name)
      end
    end
  end
end
