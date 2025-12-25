# frozen_string_literal: true

require 'pathname'

module RDFPortal
  module Repository
    class Endpoint < Pathname
      RELEASES_DIR_NAME = 'releases'
      SNAPSHOT_DIR_NAME = 'snapshot'
      WORKING_DIR_NAME = 'working'

      def initialize(path, **options)
        if (working = options.delete(:working))
          @working = Release.new(working)
        end

        super(path)
      end

      def prepare
        releases.mkpath
        snapshot.mkpath
      end

      # @return [Releases]
      def releases
        @releases ||= Releases.new(join(RELEASES_DIR_NAME))
      end

      # @return [Snapshot]
      def snapshot
        @snapshot ||= Snapshot.new(join(SNAPSHOT_DIR_NAME))
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
      CACHE_FILE_NAME = '.cache.yml'
      DB_DIR_NAME = 'db'
      LOG_DIR_NAME = 'log'
      STAT_DIR_NAME = 'stat'
      RELEASE_FILE_NAME = '.release'

      def prepare
        database_dir.mkpath
        log_dir.mkpath
        stat_dir.mkpath
      end

      def cache(&)
        Cache.open(cache_file, &)
      end

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

      # @return [Pathname]
      def stat_dir
        join STAT_DIR_NAME
      end

      # @return [Pathname]
      def release_file
        join RELEASE_FILE_NAME
      end
    end

    class Snapshot < Pathname
      CACHE_FILE_NAME = '.cache.yml'

      def [](name)
        join(name)
      end

      def cache(&)
        Cache.open(cache_file, &)
      end

      # @return [Pathname]
      def cache_file
        join CACHE_FILE_NAME
      end
    end

    class Cache
      extend Forwardable
      include Enumerable

      class << self
        def open(path)
          data = File.exist?(path) ? YAML.load_file(path, permitted_classes: [Symbol, Time]) : []

          cache = new(path, data.map(&:deep_symbolize_keys))

          return yield cache if block_given?

          cache
        end
      end

      def initialize(path, initial_value = [])
        @path = path
        @value = initial_value
      end

      def_delegators :@value, :first, :each, :last

      def add(name, files)
        @value << { name:, files: }

        save
      end

      alias << add

      def save
        File.write(@path, @value.map(&:deep_stringify_keys).to_yaml)
      end
    end
  end
end
