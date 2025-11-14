# frozen_string_literal: true

module RDFPortal
  module Interaction
    module Endpoint
      require_relative 'base'

      class Setup < Base
        boolean :force, default: false

        def execute
          repository.prepare
          repository.working.prepare

          snapshot = if !force && (snapshot_cache = repository.snapshot.cache).present?
                       load_list = datasets.map do |dataset|
                         files = RDFPortal.graph_config(dataset[:name])
                                          .flat_map { |x| Dir.glob(x[:pattern]) }
                                          .map { |x| File.realpath(x) }
                                          .sort

                         { name: dataset[:name], files: }
                       end

                       identical = snapshot_cache.zip(load_list)
                                                 .take_while { |x, y| x == y }

                       repository.working.cache do |cache|
                         snapshot_cache.take(identical.size).each do |hash|
                           cache.add(hash[:name], hash[:files])
                         end
                       end

                       identical.last&.dig(0, :name)
                     end

          server.setup(snapshot:)
        end
      end
    end
  end
end
