# frozen_string_literal: true

module RDFPortal
  module Store
    class Base
      class UnsupportedAdapter < Error; end

      class_attribute :logger, instance_writer: false, default: Logger.new(nil)

      class << self
        def environment(database_dir, datasets_dir, **config)
          adapter_class(config[:adapter]).environment(database_dir, datasets_dir, **config)
        end

        def establish_connection(**config)
          adapter_class = adapter_class(config[:adapter])
          adapter_class.new(adapter_class.new_client(**config), **config)
        end

        def start(**config)
          adapter_class(config[:adapter]).start(**config)
        end

        def stop(**config)
          adapter_class(config[:adapter]).stop(**config)
        end

        def restore(source, **config)
          adapter_class(config[:adapter]).restore(source, **config)
        end

        def publish(source, destination, **config)
          adapter_class(config[:adapter]).publish(source, destination, **config)
        end

        private

        def adapter_class(adapter)
          case adapter&.downcase
          when 'virtuoso'
            ConnectionAdapters::VirtuosoAdapter
          else
            raise UnsupportedAdapter, adapter
          end
        end
      end
    end
  end
end
