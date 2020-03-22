require "logger"

module Cryngine
  module System
    class_property log_file : IO = STDOUT
    Log = Logger.new(log_file)
    Log.level = Logger::DEBUG
    Log.formatter = Logger::Formatter.new do |severity, datetime, progname, message, io|
      label = severity.unknown? ? "ANY" : severity.to_s
      io << label[0] << " - " << datetime << " -- " << message
    end
  end
end
