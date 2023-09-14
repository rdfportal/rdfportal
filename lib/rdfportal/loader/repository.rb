# frozen_string_literal: true

require 'active_support/core_ext/hash/deep_transform_values'
require 'pathname'

module RDFPortal
  module Loader
    class Repository
      class Dataset < Pathname
        # @return [Pathname]
        def graph_file
          self / 'graph.tsv'
        end

        # @return [Pathname]
        def latest
          self / 'latest'
        end
      end

      class Datasets < Pathname
        def initialize(...)
          @datasets = {}
          super
        end

        # @return [Dataset]
        def [](name)
          @datasets[name] ||= Dataset.new(self / name)
        end
      end

      class Release < Pathname
        # @return [[Pathname, Pathname, Pathname]]
        def directories
          [database, log, snapshots]
        end

        # @return [Pathname]
        def database
          self / 'db'
        end

        # @return [Pathname]
        def log
          self / 'log'
        end

        # @return [Pathname]
        def snapshots
          self / 'snapshots'
        end
      end

      class Releases < Pathname
        def new(release = nil)
          Release.new(self / (release || DateTime.now.strftime(NEW_RELEASE_FORMAT)))
        end

        # @return [Pathname]
        def [](release)
          Release.new(self / release).realpath
        end

        # @return [Release]
        def current
          Release.new(self / 'current')
        end

        # @return [Release]
        def working
          Release.new(self / 'working')
        end
      end

      class Endpoint < Pathname
        def initialize(name, path)
          @name = name
          super(path)
        end

        # @return [Pathname]
        def config
          self / 'config.yml'
        end

        # @return [Releases]
        def releases
          Releases.new(self / 'releases')
        end
      end

      class Endpoints < Pathname
        def initialize(...)
          @endpoints = {}
          super
        end

        # @return [Endpoint]
        def [](name)
          @endpoints[name] ||= Endpoint.new(name, self / name)
        end

        # @return [Release]
        def working(name)
          Release.new(self / 'working' / name)
        end
      end

      NEW_RELEASE_FORMAT = '%Y%m%d'

      def initialize(prefix, **options)
        @prefix = Pathname.new(prefix).realdirpath
        @options = options.dup.deep_transform_values(&:freeze)
      end

      # @return [Datasets]
      def datasets
        @datasets ||= Datasets.new(@prefix / 'datasets')
      end

      # @return [Endpoints]
      def endpoints
        @endpoints ||= Endpoints.new(@prefix / 'endpoints')
      end
    end
  end
end
