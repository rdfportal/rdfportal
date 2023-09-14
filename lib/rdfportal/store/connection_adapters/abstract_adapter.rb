# frozen_string_literal: true

module RDFPortal
  module Store
    module ConnectionAdapters
      class AbstractAdapter
        ADAPTER_NAME = 'Abstract'

        class << self
          def environment(database_dir, datasets_dir, **config)
            raise NotImplementedError
          end

          def new_client(**config)
            raise NotImplementedError
          end

          def start(**config)
            raise NotImplementedError
          end

          def stop(**config)
            raise NotImplementedError
          end

          def snapshot(destination, **config)
            raise NotImplementedError
          end

          def restore(source, **config)
            raise NotImplementedError
          end

          def publish(source, destination, **config)
            raise NotImplementedError
          end
        end

        attr_reader :connection

        def initialize(connection, **config)
          @connection = connection
          @config = config
        end

        def start(**config)
          raise NotImplementedError
        end

        def stop(**config)
          raise NotImplementedError
        end

        def add_file(file, graph, **options)
          raise NotImplementedError
        end

        def exec_load(**options)
          raise NotImplementedError
        end

        def status(**options)
          raise NotImplementedError
        end

        # @return [[Process::Status, String]]
        def exec_query(query, **options)
          raise NotImplementedError
        end
      end
    end
  end
end
