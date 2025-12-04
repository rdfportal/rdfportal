# frozen_string_literal: true

module RDFPortal
  module Interaction
    module Endpoint
      require_relative 'base'

      class Load < Base
        DEFAULT_PARALLEL_COUNT = 5

        hash :load, default: {} do
          integer :parallel, default: DEFAULT_PARALLEL_COUNT
          boolean :snapshots, default: true
        end

        def execute
          if pretend
            list_datasets_by_graph
            return
          end

          server.setup_loader

          loaded = repository.working.cache.map { |x| x[:name] }

          load_list = datasets.reject { |x| loaded.include?(x[:name]) }

          if load_list.empty?
            RDFPortal.logger.info(self.class) { 'Nothing to load.' }
            return
          end

          load_list.each do |dataset|
            RDFPortal.logger.info(self.class) { "Loading #{dataset[:name]}" }

            config = RDFPortal.graph_config(dataset[:name])

            options = {
              name: dataset[:name],
              config:,
              parallel: dataset.dig(:load, :parallel) || load[:parallel],
              snapshots: load[:snapshots]
            }

            server.before_load(**options)

            server.exec_load(**options)

            repository.working.cache do |cache|
              files = config.flat_map { |x| Dir.glob(x[:pattern]) }
                            .map { |x| File.realpath(x) }
                            .sort

              cache.add(dataset[:name], files)
            end

            server.after_load(**options)
          end

          server.cleanup_loader
        end

        private

        def patterns_by_graph
          datasets.flat_map { |x| RDFPortal.graph_config(x[:name]) }
                  .group_by { |r| r[:graph] }
        end

        def list_datasets_by_graph
          warnings = Hash.new { |h, k| h[k] = [] }

          results = {
            graphs: 0,
            files: 0
          }

          list = patterns_by_graph.sort_by { |graph, _| graph }

          list.each do |graph, rows|
            pretend_output.puts "<#{graph}>:"

            files_in_graph = 0

            pretend_output.with_indent do
              rows.each do |row|
                (files = Dir.glob(row[:pattern])).each { |x| pretend_output.puts "- #{File.realpath(x)}" }

                warnings[row[:path]].push(%(No files matched with "#{row[:pattern]}")) if files.empty?

                files_in_graph += files.size
                results[:files] += files.size
              end
            end

            results[:graphs] += 1 if files_in_graph.positive?
          end

          if (v = list.size - results[:graphs]).positive?
            results[:empty_graphs] = v
          end

          pretend_output.puts "\n---"

          if warnings.present?
            pretend_output.puts 'warnings:'
            pretend_output.with_indent do
              pretend_output.puts warnings.to_yaml.sub(/\A---\s*\n/, '').gsub(/^(-.*)$/, '  \1')
            end
          end

          pretend_output.puts 'results:'
          pretend_output.with_indent do
            pretend_output.puts results.transform_keys(&:to_s).to_yaml.sub(/\A---\s*\n/, '')
          end
        end
      end
    end
  end
end
