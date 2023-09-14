# frozen_string_literal: true

require 'rdfportal/store'

module RDFPortal
  module Loader
    module Interaction
      class BaseInteraction < ActiveInteraction::Base
        string :name

        hash :directory do
          object :prefix, class: Pathname, converter: :new
        end

        protected

        # @return [Repository]
        def repository
          @repository ||= Repository.new(directory[:prefix])
        end

        # @return [Repository::Release]
        def work_dir
          repository.endpoints.working(name)
        end
      end

      class DatabaseInteraction < BaseInteraction
        hash :database, strip: false

        protected

        # @return [Hash]
        def environment
          environment = RDFPortal::Store::Base.environment(repository.endpoints.working(name).database,
                                                           repository.datasets,
                                                           **database)

          database.merge(environment: (database.dig(:environment, :load) || {})).deep_merge(environment)
        end

        # @return [Store::ConnectionAdapters::AbstractAdapter]
        def establish_connection
          @establish_connection ||= RDFPortal::Store::Base.establish_connection(**environment)
        end
      end

      require 'rdfportal/loader/interaction/connect'
      require 'rdfportal/loader/interaction/delete'
      require 'rdfportal/loader/interaction/find'
      require 'rdfportal/loader/interaction/load'
      require 'rdfportal/loader/interaction/publish'
      require 'rdfportal/loader/interaction/setup'
      require 'rdfportal/loader/interaction/status'
      require 'rdfportal/loader/interaction/stop'
    end
  end
end
