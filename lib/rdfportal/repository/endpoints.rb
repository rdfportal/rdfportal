# frozen_string_literal: true

require 'pathname'

require 'rdfportal/repository/releases'

module RDFPortal
  class Repository
    class Endpoints < Pathname
      def initialize(path)
        @endpoints = {}
        super(path)
      end

      # @return [Endpoint]
      def [](name)
        @endpoints[name] ||= Endpoint.new(join(name))
      end
    end

    class Endpoint < Pathname
      RELEASES_DIR_NAME = 'releases'
      WORKING_DIR_NAME = 'working'

      # @return [Releases]
      def releases
        @releases ||= Releases.new(join(RELEASES_DIR_NAME))
      end

      # @return [Release]
      def working
        Release.new(join(WORKING_DIR_NAME))
      end
    end
  end
end
