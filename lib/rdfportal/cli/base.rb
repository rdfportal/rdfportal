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
        opts = {}

        prefix = config.dig(:directory, :prefix) || raise(Error, 'Directory prefix not specified')

        if (working = options[:work_dir] || config.dig(:directory, :working))
          opts[:working] = Pathname.new(working).join(name)
        end

        Repository::Endpoint.new(Pathname.new(prefix).join(name), **opts)
      end
    end
  end
end
