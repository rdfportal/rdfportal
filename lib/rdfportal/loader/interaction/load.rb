# frozen_string_literal: true

require 'benchmark'
require 'csv'
require 'rdfportal/loader/interaction'

module RDFPortal
  module Loader
    module Interaction
      class Load < DatabaseInteraction
        hash :load do
          boolean :snapshots, default: false
          integer :parallel, default: 1
          array :datasets do
            hash do
              string :name
              array :files, default: nil do
                string
              end
            end
          end
        end

        string :dataset_from, default: nil

        boolean :pretend, default: false
        boolean :shutdown, default: false

        def execute
          if pretend
            list, warnings = load_list
            puts "restore from #{restore_from}" if restore_from
            puts list.to_yaml
            puts warnings.to_yaml.sub(/^---$/, "\n---\n# Warnings:") if warnings.present?
            return
          end

          total = Benchmark.realtime do
            unless work_dir.exist?
              warn 'working directory not exist'
              return
            end

            RDFPortal.logger = Store::Base.logger = Logger.new(work_dir.log / 'loader.log')

            RDFPortal::Store::Base.restore(restore_from, **environment) if restore_from.present?

            adapter = establish_connection

            (datasets = self.datasets).each_with_index do |dataset, index|
              RDFPortal.logger.info(PROGRAM_NAME) { "start loading #{dataset[:name]}" }

              dataset[:files].each do |graph, files|
                files.each do |file|
                  adapter.add_file file, graph
                end
              end

              adapter.exec_load(parallel: dataset[:parallel].presence || load[:parallel], checkpoint: load[:snapshots])
              adapter.snapshot(work_dir.snapshots / dataset[:name]) if load[:snapshots] && index != datasets.size - 1
            end

            adapter.after_load
            adapter.stop if shutdown
          end

          RDFPortal.logger.info(PROGRAM_NAME) { "total: #{total.to_i.readable_duration}" }
        end

        private

        CSV_OPTIONS = {
          col_sep: "\t",
          skip_lines: /^#/,
          headers: true,
          header_converters: :symbol
        }.freeze

        def datasets
          datasets = load[:datasets]
          datasets = datasets.drop_while { |hash| hash[:name] != dataset_from } if dataset_from.present?

          datasets.map do |dataset|
            files = Hash.new { |h, k| h[k] = [] }
            warnings = []

            (dataset[:files].presence || ["#{dataset[:name]}/graph.tsv"]).each do |graph_file|
              path = repository.datasets / graph_file

              CSV.foreach(path.to_s, **CSV_OPTIONS) do |tsv|
                matched = path.dirname.glob(tsv[:pattern])

                warnings.push(%(#{graph_file}: No files matched with "#{tsv[:pattern]}")) if matched.empty?

                # split into small group to avoid stack error
                matched.map(&:realpath).each_slice(10_000) do |g|
                  files[tsv[:graph]].push(*g.map(&:to_s))
                end
              end
            end

            {
              name: dataset[:name],
              parallel: dataset[:parallel],
              files:,
              warnings:
            }
          end
        end

        def load_list
          hash = Hash.new { |h, k| h[k] = [] }
          warnings = []

          datasets.each do |dataset|
            dataset[:files].each do |graph, files|
              files.each_slice(10_000) { |g| hash[graph].push(*g) }
            end
            warnings.push(*dataset[:warnings])
          end

          [hash, warnings]
        end

        def restore_from
          return if dataset_from.blank?

          template = load[:datasets]&.take_while { |hash| hash[:name] != dataset_from }&.last
          return unless template

          file = repository.endpoints[name].releases.current.snapshots / template[:name]
          file = repository.endpoints[name].releases.glob("**/#{template[:name]}").max unless file.exist?

          return if file.blank? || !file.exist?

          file
        end
      end
    end
  end
end
