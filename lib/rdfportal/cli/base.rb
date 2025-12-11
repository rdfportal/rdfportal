# frozen_string_literal: true

module RDFPortal
  module CLI
    class Base < Thor
      include Thor::Actions

      class << self
        def exit_on_failure?
          false
        end
      end

      private

      def repository(name, config)
        prefix = config.dig(:directory, :prefix) || raise(Error, 'Working directory not specified')

        options = {}

        if (working = config.dig(:directory, :working))
          options[:working] = Pathname.new(working).join(name)
        end

        Repository::Endpoint.new(Pathname.new(prefix).join(name), **options)
      end
    end
  end
end
