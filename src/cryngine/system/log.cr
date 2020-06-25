require "log"
require "log/entry"

module Cryngine
  Log = System::Log

  module System
    class_property log_file : IO = STDOUT
    Log = Log.new(log_file)
    Log.level = Log::Severity::Debug
    Log.formatter = Log::Formatter.new do |severity, datetime, progname, message, io|
      label = severity.unknown? ? "ANY" : severity.to_s
      io << label[0] << " - " << datetime << " -- " << message
    end
  end
end
