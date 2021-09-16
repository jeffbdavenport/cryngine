require "log"

module Cryngine
  module System
    class_property log_file : IO = STDOUT

    formatter = ::Log::Formatter.new do |entry, io|
      label = entry.severity.to_s
      # io << label[0] << " - " << entry.timestamp << " -- "
      io << entry.message
      unless entry.data.empty?
        io << " -- " << entry.data
      end
      unless entry.context.empty?
        io << " -- " << entry.context.to_s
      end
    end
    Log.setup Log::Severity::Debug, Log::IOBackend.new(log_file, formatter: formatter)
  end
end
