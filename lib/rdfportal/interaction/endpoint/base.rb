# frozen_string_literal: true

module RDFPortal
  module Interaction
    module Endpoint
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

        AVAILABLE_ADAPTERS = %w[virtuoso].freeze

        validates :'database.adapter', inclusion: { in: AVAILABLE_ADAPTERS }

        def initialize(inputs = {})
          super
          @environment = Store::Environment::LOAD
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
