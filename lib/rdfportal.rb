# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext'
require 'action_view/helpers/javascript_helper'
require 'active_interaction'
require 'digest/md5'
require 'erb'
require 'faktory'
require 'pathname'
require 'slack-notifier'
require 'tmpdir'
require 'uri'
require 'zlib'

module RDFPortal
  DATASETS_DIR_NAME = 'datasets'
  DATASET_FILE_NAME = 'dataset.yml'
  ENDPOINTS_DIR_NAME = 'endpoints'
  GRAPH_FILE_NAME = 'graph.tsv'

  def self.home
    Pathname.new(Dir.home).join('.rdfportal')
  end

  def self.vendor_lib_dir
    Pathname.new(__dir__).parent.join('vendor', 'lib')
  end

  require 'rdfportal/configuration'
  extend Configuration

  def self.config_endpoints_dir
    config_dir.join(ENDPOINTS_DIR_NAME)
  end

  def self.config_datasets_dir
    config_dir.join(DATASETS_DIR_NAME)
  end

  def self.endpoint_config(name, env = nil)
    path = config_endpoints_dir.join("#{name}.yml")

    raise Error, "File not found: #{path}" unless path.exist?

    hash = load_yaml(path)

    if env
      environment = (database = hash[:database])&.delete(:environment)

      database.merge!(environment[env]) if environment&.key?(env)
    end

    hash
  end

  def self.dataset_config(name, exception: true)
    path = config_datasets_dir.join(name, DATASET_FILE_NAME)

    unless path.exist?
      raise Error, "File not found: #{path}" if exception

      return
    end

    load_yaml(path)
  end

  def self.graph_config(name)
    path = config_datasets_dir.join(name, GRAPH_FILE_NAME)

    raise Error, "File not found: #{path}" unless path.exist?

    load_tsv(path).map do |row|
      row[:path] = path.to_s

      if row[:pattern]
        dataset = dataset_config(name, exception: false)

        datasets_dir = File.join(dataset&.dig(:directory, :prefix) || RDFPortal.datasets_dir.to_s, name)

        row[:pattern] = File.expand_path(row[:pattern], datasets_dir)
      end

      row
    end
  end

  require 'rdfportal/extension'
  require 'rdfportal/configurable'
  require 'rdfportal/docker_helper'
  require 'rdfportal/downloader'
  require 'rdfportal/error'
  require 'rdfportal/external_command'
  require 'rdfportal/interaction'
  require 'rdfportal/job'
  require 'rdfportal/logger'
  require 'rdfportal/matcher'
  require 'rdfportal/notifier'
  require 'rdfportal/resource'
  require 'rdfportal/repository'
  require 'rdfportal/resolver'
  require 'rdfportal/store'
  require 'rdfportal/version'

  extend Configurable
end
