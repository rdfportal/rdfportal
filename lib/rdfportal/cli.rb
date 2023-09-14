# frozen_string_literal: true

module RDFPortal
  class CLI
    class Generator < Thor
      desc 'config <endpoint> [dataset] [dataset] ...', 'Generate config template'

      def config(name, *datasets)
        template = ERB.new(File.read(File.expand_path('../../template/config.yml.erb', __dir__)), trim_mode: '-')

        puts template.result(binding)
      end
    end

    class Main < Thor
      class << self
        def exit_on_failure?
          true
        end
      end

      desc 'generate [SUBCOMMAND]', 'Commands for generator'
      subcommand :generate, Generator

      desc 'setup <CONFIG>', 'Setup working directory'
      option :delete_only, type: :boolean, aliases: '-d', desc: 'Delete working directory and exit'

      def setup(file)
        inputs = load_config(file).merge(delete_only: options[:delete_only])

        if options[:delete_only]
          Loader::Interaction::Delete.run!(**inputs) if Loader::Interaction::Find.run!(**inputs).present?
          return
        end

        if Loader::Interaction::Find.run!(**inputs).present?
          if yes?("Remove existing working directory for #{inputs[:name]}? [y/N]:")
            Loader::Interaction::Delete.run!(**inputs)
          else
            abort 'Aborted'
          end
        end

        Loader::Interaction::Setup.run!(**inputs)
      end

      desc 'load <CONFIG>', 'Load datasets to working directory'
      option :dataset_from, type: :string, aliases: '-d', desc: 'Start from template'
      option :pretend, type: :boolean, aliases: '-p', desc: 'Run but do not load actually'
      option :shutdown, type: :boolean, aliases: '-s', desc: 'Shutdown server after loading'

      def load(file)
        inputs = load_config(file).merge(dataset_from: options[:dataset_from],
                                         pretend: options[:pretend],
                                         shutdown: options[:shutdown])

        Loader::Interaction::Load.run!(**inputs)
      end

      desc 'status <CONFIG>', 'Show status'
      option :verbose, type: :boolean, aliases: '-v', desc: 'Output more detailed information'

      def status(file)
        inputs = load_config(file).merge(verbose: options[:verbose])

        Loader::Interaction::Status.run!(**inputs)
      end

      desc 'stop <CONFIG>', 'Stop server for working directory'

      def stop(file)
        inputs = load_config(file)

        Loader::Interaction::Stop.run!(**inputs)
      end

      desc 'publish <CONFIG>', 'Publish working directory to new release'
      option :release, type: :string, aliases: '-r', desc: 'Release number'

      def publish(file)
        inputs = load_config(file).merge(release: options[:release])

        Loader::Interaction::Publish.run!(**inputs)
      end

      no_commands do
        def load_config(file)
          if File.exist?((env = File.join(Dir.home, '.rdfportal', '.env')))
            require 'dotenv'
            Dotenv.load(env)
          end

          YAML.load(ERB.new(File.read(file)).result, aliases: true).with_indifferent_access
        end
      end
    end
  end
end
