# frozen_string_literal: true

module RDFPortal
  module CLI
    require 'rdfportal/cli/generate'
    require 'rdfportal/cli/statistics'

    class Main < Thor
      include Configurable

      class << self
        def exit_on_failure?
          true
        end
      end

      desc 'generate [SUBCOMMAND]', 'Commands for generator'
      subcommand :generate, Generate

      desc 'statistics [SUBCOMMAND]', 'Commands for statistics'
      subcommand :statistics, Statistics

      desc 'fetch <endpoint name>', 'Fetch datasets'
      option :pretend, aliases: '-p', type: :boolean, desc: 'Run but do not fetch actually'
      option :debug, type: :boolean, desc: 'Show error stack trace'

      def fetch(name)
        datasets = load_yaml(File.join(RDFPortal.config_dir, ENDPOINTS_DIR_NAME, "#{name}.yml")).dig(:load, :datasets)

        result = RDFPortal::Interaction::FetchDatasets.run!(datasets:, pretend: options[:pretend])

        return unless options[:pretend]

        result.each do |key, contents|
          contents.each do |content|
            from = content.uri
            to = File.join(*(Array(key) + [Time.now.strftime(Repository::Dataset::VERSION_FORMAT), content.output_path]))
            puts "#{from} -> #{to}"
          end
        end
      rescue StandardError => e
        say_error e.message
        say_error e.full_message if options[:debug]
        exit 1
      end

      desc 'version', 'Show version number'

      def version
        puts "#{File.basename($PROGRAM_NAME)} #{VERSION}"
      end

      map %w[--version -v] => :version
    end
  end
end
