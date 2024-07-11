# frozen_string_literal: true

require 'active_interaction'
require 'active_support'
require 'dotenv'
require 'erb'
require 'inifile'
require 'net/ftp'
require 'nokogiri'
require 'thor'
require 'tty-command'
require 'typhoeus'
require 'uri'

module RDFPortal
  # Base error class for the module
  class Error < StandardError; end

  class FileNotFound < Error
    attr_reader :path

    def initialize(path)
      @path = path
      super "File not found: #{path}"
    end
  end

  class DirectoryNotFound < Error
    attr_reader :path

    def initialize(path)
      @path = path
      super "Directory not found: #{path}"
    end
  end

  class InvalidConfigurationError < Error
    attr_accessor :input, :path

    def message
      [super, "#{input}#{" in #{path}" if path}"].join("\n")
    end
  end

  class ParameterNotDefined < Error; end

  class HTTPRequestError < Error
    def initialize(response)
      @response = response
      super("#{response.response_code} #{response.status_message}")
    end

    def message
      "#{super}, url = #{@response.effective_url}, body = #{@response.body}"
    end
  end

  module FTPClient
    LOG_NAME = 'FTP'

    def ftp_client(uri, **options)
      return @client if @client

      return (@client = options[:ftp_client]) if options[:ftp_client].present?

      ftp = Net::FTP.new(uri.host)
      ftp.passive = options[:passive] if options.key?(:passive)
      ftp.login((user = options[:user].presence || 'anonymous'), (password = options[:password].presence))

      RDFPortal.logger.debug(LOG_NAME) do
        msg = "login to #{uri.host} (user: #{user}, password: "
        msg += password.blank? ? 'none' : ('*' * password.length)
        msg + ", passive: #{ftp.passive})"
      end

      @client = options[:ftp_client] = ftp
    end
  end

  module ExternalCommand
    # @return [TTY::Command::Result]
    def external_command(*cmd, **options, &)
      cmd = cmd.join(' ')
      options = { stdout: true, stderr: true, log: true }.merge(options)

      RDFPortal.logger.debug('EXT CMD') { cmd } if options[:log]

      TTY::Command.new(printer: :null).run(cmd, env: options[:env] || {}) do |out, err|
        RDFPortal.logger.debug('STDOUT') { out.chomp } if out.present? && options[:log]
        yield out.chomp if block_given? && out.present? && options[:stdout]

        RDFPortal.logger.debug('STDERR') { err.chomp } if err.present? && options[:log]
        yield err.chomp if block_given? && err.present? && options[:stderr]
      end
    end
  end

  module Configurable
    def load_yaml(file)
      yaml = ERB.new(File.read(file)).result
      obj = YAML.load(yaml, aliases: true, permitted_classes: [Time])

      obj.is_a?(Array) ? { data: obj }.with_indifferent_access[:data] : Hash(obj).with_indifferent_access
    end
  end

  ENV_FILE = File.join(Dir.home, '.rdfportal', 'config')
  ENV_PREFIX = 'RDFPORTAL_'
  REQUIRED_ENVS = %w[RDFPORTAL_DATASETS_DIR RDFPORTAL_ENDPOINTS_DIR RDFPORTAL_CONFIG_DIR].freeze
  private_constant :ENV_FILE, :ENV_PREFIX, :REQUIRED_ENVS

  Dotenv.load(ENV_FILE) if File.exist?(ENV_FILE)
  if (missing = REQUIRED_ENVS - ENV.keys).present?
    warn "Missing configuration #{missing.to_sentence} in #{ENV_FILE}"
    exit 1
  end

  REQUIRED_ENVS.each do |env|
    define_singleton_method(env.delete_prefix(ENV_PREFIX).downcase) { ENV.fetch(env) }
  end

  TEMPLATE_DIR = File.expand_path('../template', __dir__ || raise(Error, '__dir__ returns nil'))

  DATASETS_DIR_NAME = 'datasets'
  DATASET_FILE_NAME = 'dataset.yml'
  GRAPH_FILE_NAME = 'graph.tsv'
  ENDPOINTS_DIR_NAME = 'endpoints'

  require 'rdfportal/cli'
  require 'rdfportal/dataset'
  require 'rdfportal/interaction'
  require 'rdfportal/loader'
  require 'rdfportal/logger'
  require 'rdfportal/matcher'
  require 'rdfportal/repository'
  require 'rdfportal/store'
  require 'rdfportal/version'

  @logger = RDFPortal::Logger.new(nil)

  attr_accessor :logger

  module_function :logger, :logger=
end

class Integer
  def readable_duration
    s = (self % 60).round(3)
    m = (self / 60).to_i % 60
    h = (self / 60 / 60).to_i % 24
    d = (self / 60 / 60 / 24).to_i

    "#{"#{d}d " if d.positive?}#{format('%<h>02d:%<m>02d:%<s>02d', { h:, m:, s: })}"
  end
end

