# frozen_string_literal: true

require 'action_view/helpers/javascript_helper'
require 'active_interaction'
require 'active_support'
require 'active_support/core_ext'
require 'digest/md5'
require 'erb'
require 'faktory'
require 'pathname'
require 'slack-notifier'
require 'tmpdir'
require 'uri'

module RDFPortal
  DATASETS_DIR_NAME = 'datasets'
  DATASET_FILE_NAME = 'dataset.yml'
  ENDPOINTS_DIR_NAME = 'endpoints'
  GRAPH_FILE_NAME = 'graph.tsv'

  require 'rdfportal/configuration'
  extend Configuration

  def self.home
    Pathname.new(Dir.home).join('.rdfportal')
  end

  def self.config_endpoints_dir
    config_dir.join(ENDPOINTS_DIR_NAME)
  end

  def self.config_datasets_dir
    config_dir.join(DATASETS_DIR_NAME)
  end

  # @deprecated use `directory.prefix` in endpoint.yaml
  def self.endpoints_dir
    Pathname.new(ENV.fetch('RDFPORTAL_ENDPOINTS_DIR'))
  end

  def self.endpoint_yaml(name)
    path = config_endpoints_dir.join("#{name}.yml")

    raise Error, "File not found: #{path}" unless path.exist?

    load_yaml(path)
  end

  def self.dataset_yaml(name)
    path = config_datasets_dir.join(name, DATASET_FILE_NAME)

    raise Error, "File not found: #{path}" unless path.exist?

    load_yaml(path)
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
  require 'rdfportal/remote_directory'
  require 'rdfportal/repository'
  require 'rdfportal/resolver'
  require 'rdfportal/version'

  extend Configurable
end
