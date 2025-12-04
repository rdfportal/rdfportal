# frozen_string_literal: true

module RDFPortal
  module Store
    class AbstractAdapter
      attr_reader :name, :repository, :options

      def initialize(name, repository, **options)
        @name = name
        @repository = repository
        @options = options
      end

      def server_running?
        raise NotImplementedError
      end

      def start_if_needed!
        raise NotImplementedError
      end

      def stop!
        raise NotImplementedError
      end

      def setup(**options)
        raise NotImplementedError
      end

      def status
        raise NotImplementedError
      end

      def setup_loader(**options)
        raise NotImplementedError
      end

      def cleanup_loader(**options)
        raise NotImplementedError
      end

      def before_load(**options)
        raise NotImplementedError
      end

      def exec_load(**options)
        raise NotImplementedError
      end

      def after_load(**options)
        raise NotImplementedError
      end

      def publish(**options)
        raise NotImplementedError
      end

      def environment(**options)
        raise NotImplementedError
      end

      def statistics(**options)
        raise NotImplementedError
      end
    end
  end
end
