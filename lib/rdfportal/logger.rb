# frozen_string_literal: true

module RDFPortal
  class Logger < ActiveSupport::BroadcastLogger
    def initialize(*args, **options)
      logdev = args.first
      broadcast = options.delete(:broadcast)

      options[:level] ||= if ENV['LOG_LEVEL'].present?
                            ENV['LOG_LEVEL'].downcase
                          elsif RDFPortal.debug?
                            ::Logger::Severity::DEBUG
                          else
                            ::Logger::Severity::INFO
                          end

      options[:formatter] ||= ::Logger::Formatter.new

      loggers = [ActiveSupport::Logger.new(*args, **options)]

      if broadcast != false && [nil, File::NULL, $stdout, $stderr].none?(logdev)
        loggers << ActiveSupport::Logger.new($stderr, **options)
      end

      super(*loggers)
    end
  end

  # Thread-safe logger
  class << self
    THREAD_KEY = :rdfportal_logger

    def logger
      Thread.current[THREAD_KEY] || if debug?
                                      Logger.new($stderr, level: ::Logger::Severity::DEBUG)
                                    else
                                      Logger.new(nil)
                                    end
    end

    def logger=(logger)
      Thread.current[THREAD_KEY] = logger
    end

    def with_logger(logger)
      prev = Thread.current[THREAD_KEY]
      Thread.current[THREAD_KEY] = logger
      yield
    ensure
      Thread.current[THREAD_KEY] = prev
    end

    def reset_logger!
      Thread.current[THREAD_KEY] = nil
    end
  end
end
