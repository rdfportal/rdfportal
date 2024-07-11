# frozen_string_literal: true

require 'pathname'

module RDFPortal
  class Repository
    class Datasets < Pathname
      def initialize(path)
        @path = path
        @datasets = {}
        super(path)
      end

      # @return [Dataset]
      def [](name)
        @datasets[name] ||= Dataset.new(join(name))
      end
    end

    class Dataset < Pathname
      include Configurable

      CACHE_FILE_NAME = 'cache.yml'
      LATEST_DIR_NAME = 'latest'
      VERSION_FORMAT = '%Y%m%d'
      VERSION_REGEX = /\A[1-9]\d{7}\Z/

      def initialize(path)
        @path = path
        @groups = {}
        super(@path)
      end

      def [](name)
        @groups[name] ||= Dataset.new(join(name))
      end

      def latest
        join(LATEST_DIR_NAME)
      end

      def up_to_date?(contents)
        return false unless (cache_file = latest.join(CACHE_FILE_NAME)).exist?

        cache = load_yaml(cache_file)

        contents.none? { |x| (y = cache[x.output_path]).present? ? x.modified?(y) : true }
      end
    end
  end
end
