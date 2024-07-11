# frozen_string_literal: true

require 'active_support/core_ext/hash/deep_transform_values'
require 'pathname'

require 'rdfportal/repository/datasets'
require 'rdfportal/repository/endpoints'
require 'rdfportal/repository/releases'

module RDFPortal
  class Repository
    def initialize(**options)
      @options = options.dup
    end

    # @return [Datasets]
    def datasets
      @datasets ||= Datasets.new(@options[:datasets] || RDFPortal.datasets_dir)
    end

    # @return [Endpoints]
    def endpoints
      @endpoints ||= Endpoints.new(@options[:endpoints] || RDFPortal.endpoints_dir)
    end
  end
end
