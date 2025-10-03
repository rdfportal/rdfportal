# frozen_string_literal: true

module RDFPortal
  module Interaction
    module Endpoint
      DEFAULT_PARALLEL_COUNT = 5

      # A base class representing the structure of endpoint.yml
      class Base < Interaction::Base
        include Configurable

        string :name

        hash :directory do
          string :prefix
        end

        array :datasets, default: [] do
          hash do
            string :name
            integer :parallel, default: DEFAULT_PARALLEL_COUNT
          end
        end

        hash :database, strip: false do
          string :adapter
          hash :environment do
            hash :load, strip: false
            hash :stat, strip: false
          end
        end

        hash :load do
          boolean :snapshots, default: false
          integer :parallel, default: DEFAULT_PARALLEL_COUNT
        end

        AVAILABLE_ADAPTERS = %w[virtuoso].freeze

        validates :'directory.prefix', existence: true
        validates :'database.adapter', inclusion: { in: AVAILABLE_ADAPTERS }
        # validate :dataset_config
        validates :environment, inclusion: { in: %i[fetch load stat] }

        attr_reader :environment

        def initialize(inputs = {})
          @environment = inputs.delete(:environment)
          super
        end

        private

        # @return [Pathname]
        def directory_prefix
          Pathname.new(directory[:prefix])
        end

        def repository
          @repository ||= Repository::Endpoint.new(directory_prefix.join(name))
        end

        # @return [Pathname]
        def datasets_config_dir
          Pathname.new(directory.dig(:datasets, :config))
        end

        # @return [Pathname]
        def datasets_dir
          Pathname.new(directory.dig(:datasets, :store))
        end

        # def database_config
        #   return @database_config if @database_config
        #
        #   config = database.deep_symbolize_keys
        #   environment = config.dig(:environment, @env.to_sym) || {}
        #   config[:environment] = environment
        #
        #   case config[:adapter]
        #   when 'virtuoso'
        #     config.deep_merge!(ini: working.database.join('virtuoso.ini'),
        #                        environment: {
        #                          Database: {
        #                            DatabaseFile: working.database.join('virtuoso.db'),
        #                            ErrorLogFile: working.database.join('virtuoso.log'),
        #                            LockFile: working.database.join('virtuoso.lck'),
        #                            TransactionFile: working.database.join('virtuoso.trx'),
        #                            xa_persistent_file: working.database.join('virtuoso.pxa')
        #                          },
        #                          TempDatabase: {
        #                            DatabaseFile: working.database.join('virtuoso-temp.db'),
        #                            TransactionFile: working.database.join('virtuoso-temp.trx')
        #                          },
        #                          Parameters: {
        #                            DirsAllowed: RDFPortal.datasets_dir
        #                          }
        #                        })
        #   end
        #
        #   @database_config = config
        # end
      end
    end
  end
end
