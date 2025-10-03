# frozen_string_literal: true

require 'pathname'

module RDFPortal
  module Repository
    class Endpoint < Pathname
      RELEASES_DIR_NAME = 'releases'
      SNAPSHOT_DIR_NAME = 'snapshot'
      WORKING_DIR_NAME = 'working'

      # @return [Releases]
      def releases
        @releases ||= Releases.new(join(RELEASES_DIR_NAME))
      end

      # @return [Pathname]
      def snapshot_dir
        join(SNAPSHOT_DIR_NAME)
      end

      # @return [Release]
      def working
        @working ||= Release.new(join(WORKING_DIR_NAME))
      end
    end

    class Releases < Pathname
      NEW_RELEASE_FORMAT = '%Y%m%d'
      CURRENT_DIR_NAME = 'current'

      def initialize(path)
        @releases = {}
        super
      end

      # @return [Pathname]
      def [](release)
        @releases[release] ||= Release.new(join(release))
      end

      # @return [Release]
      def new(release = nil)
        send(:[], release || Time.now.strftime(NEW_RELEASE_FORMAT))
      end

      # @return [Release]
      def current
        send(:[], CURRENT_DIR_NAME)
      end
    end

    class Release < Pathname
      CACHE_FILE_NAME = 'cache.yml'
      DB_DIR_NAME = 'db'
      LOG_DIR_NAME = 'log'

      # @return [Pathname]
      def cache_file
        join CACHE_FILE_NAME
      end

      # @return [Pathname]
      def database_dir
        join DB_DIR_NAME
      end

      # @return [Pathname]
      def log_dir
        join LOG_DIR_NAME
      end
    end
  end
end
