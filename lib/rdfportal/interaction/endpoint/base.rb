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
          hash default: -> {} do
            string :name
            integer :parallel, default: nil
          end
        end

        AVAILABLE_ADAPTERS = %w[virtuoso].freeze

        validates :'database.adapter', inclusion: { in: AVAILABLE_ADAPTERS }

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
          @server ||= Store::ServerManager.for(name, repository:, working_dir:, database:, datasets:)
        end
      end
    end
  end
end
