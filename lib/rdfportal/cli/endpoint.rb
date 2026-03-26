# frozen_string_literal: true

module RDFPortal
  module CLI
    require_relative 'base'

    class Endpoint < Base
      ENVIRONMENTS = Store::Environment.constants.map { |c| Store::Environment.const_get(c) }

      desc 'config <NAME>', 'Parse, resolve and render endpoint configuration'
      option :environment, aliases: '-e', type: :string, enum: ENVIRONMENTS, desc: 'Endpoint environment'

      def config(name)
        environment = check_environment

        interaction = Interaction::Endpoint::Base.new(name:, **RDFPortal.endpoint_config(name, environment))

        raise(Error, interaction.errors.input_error_messages) unless interaction.valid?

        say JSON.pretty_generate(interaction.config)
      rescue Error => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end

      desc 'fetch <NAME>', 'Fetch datasets loaded to the endpoint'
      option :continue, aliases: '-c', type: :boolean, desc: 'Continue getting last failed dataset'
      option :from, aliases: '-f', type: :string, desc: 'Start from this dataset'
      option :pretend, aliases: '-p', type: :boolean, desc: 'Run but do not fetch actually'

      def fetch(name)
        RDFPortal.logger = RDFPortal::Logger.new($stderr)

        config = RDFPortal.endpoint_config(name, :load)

        datasets = config[:datasets].reject { |x| x.dig(:fetch, :disable) }

        if options[:from] && (index = datasets.index { |x| x[:name] == options[:from] })
          datasets = datasets[index..]
        end

        datasets.each do |dataset|
          next if dataset.dig(:fetch, :disable) == true
          next unless File.exist?(RDFPortal.dataset_config_path(dataset[:name]))

          Dataset.new.invoke(:fetch, [dataset[:name]], **options.slice(:continue, :pretend))
        end
      end

      desc 'setup <NAME>', 'Setup database'
      option :force, aliases: '-f', type: :boolean, desc: 'Start from empty database even if snapshot is available'

      def setup(name)
        config = RDFPortal.endpoint_config(name, :load)
        repo = repository(name, config)

        if repo.working.exist?
          if yes?('Working directory already exists. Remove it? [y/N]', :yellow)
            RDFPortal.logger = RDFPortal::Logger.new($stderr)

            Interaction::Endpoint::Stop.run!(name:, **config, repository: repo, options: { force: true })
            FileUtils.rm_rf(repo.working)
          else
            abort 'Aborted.'
          end
        end

        # ensure log directory exists
        repo.working.prepare

        RDFPortal.logger = RDFPortal::Logger.new(repo.working.log_dir.join('setup.log'))

        Interaction::Endpoint::Setup.run!(name:, **config, repository: repo, force: options[:force])
      rescue Error => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end

      desc 'load <NAME>', 'Load datasets'
      option :pretend, aliases: '-p', type: :boolean, desc: 'Run but do not load actually'

      def load(name)
        config = RDFPortal.endpoint_config(name, :load)
        repo = repository(name, config)

        unless repo.working.exist?
          abort "Working directory does not exist. Run `rdfportal endpoint setup #{name}` first."
        end

        RDFPortal.logger = if options[:pretend]
                             RDFPortal::Logger.new($stderr)
                           else
                             RDFPortal::Logger.new(repo.working.log_dir.join('load.log'))
                           end

        action = Interaction::Endpoint::Load.run(name:, **config, repository: repo, pretend: options[:pretend])

        raise(Error, action.errors.input_error_messages) unless action.valid?

        say action.result unless options[:pretend]
      rescue Error => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end

      desc 'start <NAME>', 'Start database for loading'

      def start(name)
        config = RDFPortal.endpoint_config(name, :load)
        repo = repository(name, config)

        unless repo.working.exist?
          abort "Working directory does not exist. Run `rdfportal endpoint setup #{name}` first."
        end

        RDFPortal.logger = RDFPortal::Logger.new($stderr)

        Interaction::Endpoint::Start.run!(name:, **config, repository: repo, environment: :load)
      rescue Error => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end

      desc 'stop <NAME>', 'Stop database for loading'

      def stop(name)
        config = RDFPortal.endpoint_config(name, :load)
        repo = repository(name, config)

        RDFPortal.logger = RDFPortal::Logger.new($stderr)

        Interaction::Endpoint::Stop.run!(name:, **config, repository: repo, environment: :load)
      rescue Error => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end

      desc 'publish <NAME>', 'Publish database'
      option :work_dir, aliases: '-w', type: :string, desc: 'Use temporary working directory'

      def publish(name)
        config = RDFPortal.endpoint_config(name, :load)
        repo = repository(name, config)

        unless repo.working.exist?
          abort "Working directory does not exist. Run `rdfportal endpoint setup #{name}` first."
        end

        RDFPortal.logger = RDFPortal::Logger.new(repo.working.log_dir.join('publish.log'))

        action = Interaction::Endpoint::Publish.run(name:, **config, repository: repo)

        raise(Error, action.errors.input_error_messages) unless action.valid?
      rescue Error, ActiveInteraction::InvalidInteractionError => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end

      desc 'console <NAME>', 'Start console for debugging'
      option :environment, aliases: '-e', type: :string, desc: 'Endpoint environment'

      def console(name, command = nil)
        RDFPortal.logger = RDFPortal::Logger.new($stderr, level: ::Logger::Severity::DEBUG)

        environment = check_environment

        config = RDFPortal.endpoint_config(name, environment)
        repository = repository(name, config)
        server = Store::ServerManager.for(name, **config, repository:, environment:)

        Kernel.define_method(:config) do
          config
        end

        Kernel.define_method(:repository) do
          repository
        end

        Kernel.define_method(:server) do
          server
        end

        Kernel.define_method(:adapter) do
          server.adapter
        end

        if command
          eval command
        else
          require 'irb'
          ARGV.clear
          IRB.start(__FILE__)
        end
      end

      private

      def check_environment
        environment = options.fetch(:environment, 'load').to_sym

        unless Store::Environment.constants.any? { |c| Store::Environment.const_get(c) == environment }
          abort "Unknown environment: #{environment}"
        end

        environment
      end
    end
  end
end
