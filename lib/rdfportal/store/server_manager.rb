# frozen_string_literal: true

require 'forwardable'

module RDFPortal
  module Store
    class ServerManager
      extend Forwardable

      class << self
        def for(name, **options)
          new(adapter_class(options.dig(:database, :adapter)).create(name, **options))
        end

        def adapter_class(name)
          case name
          when 'virtuoso'
            if RDFPortal.virtuoso == :docker
              raise NotImplementedError
            else
              require 'rdfportal/store/adapters/virtuoso_adapter'
              Adapters::VirtuosoAdapter
            end
          else
            raise Error, "Unsupported adapter: #{name}"
          end
        end
      end

      attr_reader :adapter

      def initialize(adapter)
        @adapter = adapter
      end

      def_delegators :@adapter,
                     :server_running?,
                     :start_if_needed!,
                     :stop!,
                     :setup,
                     :status,
                     :setup_loader,
                     :cleanup_loader,
                     :before_load,
                     :exec_load,
                     :after_load,
                     :publish,
                     :environment,
                     :statistics
    end
  end
end
