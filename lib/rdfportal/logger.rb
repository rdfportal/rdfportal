# frozen_string_literal: true

module RDFPortal
  class Logger < ActiveSupport::BroadcastLogger
    def initialize(logdev)
      logger_options = {
        level: ENV['LOG_LEVEL'].presence&.downcase || ::Logger::Severity::INFO,
        formatter: ::Logger::Formatter.new
      }

      loggers = [ActiveSupport::Logger.new(logdev, **logger_options)]
      loggers << ActiveSupport::Logger.new($stderr, **logger_options) unless [$stdout, $stderr].any?(logdev)

      super(*loggers)
    end
  end
end
