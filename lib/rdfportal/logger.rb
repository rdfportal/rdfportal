# frozen_string_literal: true

module RDFPortal
  class Logger < ActiveSupport::Logger
    def initialize(logdev, **options)
      super(logdev, level: options[:level] || ::Logger::Severity::INFO)

      @formatter = ::Logger::Formatter.new

      extend(ActiveSupport::Logger.broadcast(self.class.new($stderr))) unless [$stdout, $stderr].any?(logdev)
    end
  end
end
