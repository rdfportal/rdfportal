# frozen_string_literal: true

require 'pathname'

module RDFPortal
  module Interaction
    class Base < ActiveInteraction::Base
      protected

      # @return [Repository]
      def repository
        @repository ||= Repository.new
      end

      def config_dir
        Pathname.new(RDFPortal.config_dir)
      end

      def time
        t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        yield
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - t1
      end
    end

    class Endpoint < Base
      string :name

      protected

      # @return [Repository::Releases]
      def releases
        repository.endpoints[name].releases
      end

      # @return [Repository::Release]
      def work_dir
        repository.endpoints[name].working
      end
    end

    require 'rdfportal/interaction/fetch_dataset'
    require 'rdfportal/interaction/fetch_datasets'
    require 'rdfportal/interaction/list_contents'
    require 'rdfportal/interaction/resolve_parameter'
  end
end
