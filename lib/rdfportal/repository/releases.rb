# frozen_string_literal: true

require 'date'
require 'pathname'

module RDFPortal
  class Repository
    class Releases < Pathname
      NEW_RELEASE_FORMAT = '%Y%m%d'
      CURRENT_DIR_NAME = 'current'

      def initialize(path)
        @releases = {}
        super(path)
      end

      # @return [Pathname]
      def [](release)
        @releases[release] ||= Release.new(join(release))
      end

      def new(release = nil)
        Release.new(join(release || Time.now.strftime(NEW_RELEASE_FORMAT)))
      end

      # @return [Release]
      def current
        Release.new(join(CURRENT_DIR_NAME))
      end
    end

    class Release < Pathname
      SNAPSHOTS_DIR_NAME = 'snapshots'
      DB_DIR_NAME = 'db'
      LOG_DIR_NAME = 'log'

      # @return [[Pathname, Pathname, Pathname]]
      def directories
        [database, log, snapshots]
      end

      # @return [Pathname]
      def database
        join DB_DIR_NAME
      end

      # @return [Pathname]
      def log
        join LOG_DIR_NAME
      end

      # @return [Pathname]
      def snapshots
        join SNAPSHOTS_DIR_NAME
      end
    end
  end
end
