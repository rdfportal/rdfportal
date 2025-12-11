# frozen_string_literal: true

module RDFPortal
  module Interaction
    module Endpoint
      DEFAULT_PARALLEL_COUNT = 5

      # A base class representing the structure of endpoint.yml
      class Base < Interaction::Base
        string :name

        hash :directory do
          string :prefix
          string :working, default: nil
        end

        hash :database, strip: false do
          string :adapter
        end

        array :datasets, default: [] do
          hash do
            string :name
            hash :load, default: nil do
              integer :parallel, default: nil
              boolean :snapshots, default: nil
            end
            hash :stat, default: nil do
              boolean :disable, default: nil
            end
          end
        end

        hash :load, default: {} do
          integer :parallel, default: DEFAULT_PARALLEL_COUNT
          boolean :snapshots, default: true
        end

        hash :stat, default: {} do
          boolean :graph, default: true
          string :endpoint, default: nil
        end

        hash :publish, default: {} do
          flex_array :postprocess, default: [] do
            hash do
              string :action
              string :file, default: nil
              string :script, default: nil
              hash :environments, default: nil
            end
          end
        end

        AVAILABLE_ADAPTERS = %w[virtuoso].freeze

        validates :'database.adapter', inclusion: { in: AVAILABLE_ADAPTERS }

        attr_reader :environment

        def initialize(inputs = {})
          env = inputs.delete(:environment)&.to_sym
          @environment ||= (env || Store::Environment::LOAD)
          super
        end

        private

        # @return [Pathname]
        def directory_prefix
          Pathname.new(directory[:prefix])
        end

        def repository
          @repository ||= begin
                            options = {}
                            options[:working] = Pathname.new(directory[:working]).join(name) if directory[:working]

                            Repository::Endpoint.new(directory_prefix.join(name), **options)
                          end
        end

        # @deprecated
        def working_dir
          (directory[:working] ? Pathname.new(directory[:working]) : directory_prefix.join('working')).join(name)
        end

        def server
          @server ||= Store::ServerManager.for(name,
                                               repository:,
                                               working_dir:,
                                               database:,
                                               datasets:,
                                               stat:,
                                               environment: @environment)
        end
      end
    end
  end
end
