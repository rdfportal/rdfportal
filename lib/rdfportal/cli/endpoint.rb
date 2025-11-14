# frozen_string_literal: true

module RDFPortal
  module CLI
    class Endpoint < Thor
      class << self
        def exit_on_failure?
          true
        end
      end

      desc 'config <NAME>', 'Parse, resolve and render endpoint configuration'

      def config(name)
        interaction = Interaction::Endpoint::Base.new(name:, **RDFPortal.endpoint_config(name, :load))

        raise(Error, interaction.errors.input_error_messages) unless interaction.valid?

        say JSON.pretty_generate(interaction.config)
      rescue Error => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end

      desc 'setup <NAME>', 'Setup database'
      option :force, aliases: '-f', type: :boolean, desc: 'Start from empty database even if snapshot is available'

      def setup(name)
        config = RDFPortal.endpoint_config(name, :load)
        repo = repository(name, config)

        if repo.working.exist?
          if yes?('Working directory already exists. Remove it? [y/N]', :yellow)
            RDFPortal.logger = RDFPortal::Logger.new($stderr)

            Interaction::Endpoint::Stop.run!(name:, **config)
            FileUtils.rm_rf(repo.working)
          else
            abort 'Aborted.'
          end
        end

        repo.working.prepare

        RDFPortal.logger = RDFPortal::Logger.new(repo.working.log_dir.join('setup.log'))

        Interaction::Endpoint::Setup.run!(name:, **config, force: options[:force])
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

        action = Interaction::Endpoint::Load.run(name:, **config, pretend: options[:pretend])

        raise(Error, action.errors.input_error_messages) unless action.valid?

        say action.result unless options[:pretend]
      rescue Error => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end

      desc 'start <NAME>', 'Start database'

      def start(name)
        config = RDFPortal.endpoint_config(name, :load)
        repo = repository(name, config)

        unless repo.working.exist?
          abort "Working directory does not exist. Run `rdfportal endpoint setup #{name}` first."
        end

        RDFPortal.logger = RDFPortal::Logger.new($stderr)

        Interaction::Endpoint::Start.run!(name:, **config)
      rescue Error => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end

      desc 'stop <NAME>', 'Stop database'

      def stop(name)
        config = RDFPortal.endpoint_config(name, :load)

        RDFPortal.logger = RDFPortal::Logger.new($stderr)

        Interaction::Endpoint::Stop.run!(name:, **config)
      rescue Error => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end

      desc 'publish <NAME>', 'Publish database'

      def publish(name)
        config = RDFPortal.endpoint_config(name, :load)
        repo = repository(name, config)

        unless repo.working.exist?
          abort "Working directory does not exist. Run `rdfportal endpoint setup #{name}` first."
        end

        RDFPortal.logger = RDFPortal::Logger.new(repo.working.log_dir.join('publish.log'))

        action = Interaction::Endpoint::Publish.run(name:, **config)

        raise(Error, action.errors.input_error_messages) unless action.valid?
      rescue Error, ActiveInteraction::InvalidInteractionError => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end

      desc 'console <NAME>', 'Start console for debugging'

      def console(name, command = nil)
        RDFPortal.logger = RDFPortal::Logger.new($stderr, level: ::Logger::Severity::DEBUG)

        config = RDFPortal.endpoint_config(name, :load)
        repository = repository(name, config)
        server = Store::ServerManager.for(name, **config, repository:)

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

      no_commands do
        def repository(name, config)
          prefix = config.dig(:directory, :prefix) || raise(Error, 'Working directory not specified')

          options = {}

          if (working = config.dig(:directory, :working))
            options[:working] = Pathname.new(working).join(name)
          end

          Repository::Endpoint.new(Pathname.new(prefix).join(name), **options)
        end
      end
    end
  end
end
