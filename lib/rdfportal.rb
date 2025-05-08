# frozen_string_literal: true

require 'active_interaction'
require 'active_support'
require 'erb'
require 'github_api'
require 'net/ftp'
require 'nokogiri'
require 'open-uri'
require 'pathname'
require 'thor'
require 'tty-command'
require 'typhoeus'
require 'yaml'

module RDFPortal
  # Base error class for the module
  class Error < StandardError; end
  class FileNotFound < Error; end

  require 'rdfportal/cli'
  require 'rdfportal/loader'
  require 'rdfportal/store'
  require 'rdfportal/version'

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

  def logger
    @logger ||= Logger.new(nil)
  end

  def logger=(logger)
    @logger = logger
  end

  module_function :logger, :logger=
end
