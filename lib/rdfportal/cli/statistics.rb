# frozen_string_literal: true

module RDFPortal
  module CLI
    require_relative 'base'

    class Statistics < Base
      class << self
        def exit_on_failure?
          true
        end
      end

      desc 'start <NAME>', 'Start database for statistics'

      def start(name)
        config = RDFPortal.endpoint_config(name, :stat)
        repo = repository(name, config)

        unless repo.working.exist?
          abort "Working directory does not exist. Run `rdfportal endpoint setup #{name}` first."
        end

        RDFPortal.logger = RDFPortal::Logger.new($stderr)

        Interaction::Endpoint::Start.run!(name:, **config, repository: repo, environment: :stat)
      rescue Error => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end

      desc 'stop <NAME>', 'Stop database for statistics'

      def stop(name)
        config = RDFPortal.endpoint_config(name, :stat)
        repo = repository(name, config)

        RDFPortal.logger = RDFPortal::Logger.new($stderr)

        Interaction::Endpoint::Stop.run!(name:, **config, repository: repo, environment: :stat)
      rescue Error => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end

      desc 'execute <NAME>', 'Collect statistics'

      def execute(name)
        config = RDFPortal.endpoint_config(name, :stat)
        repo = repository(name, config)

        unless repo.working.exist?
          abort "Working directory does not exist. Run `rdfportal endpoint setup #{name}` and `rdfportal endpoint load #{name}` first."
        end

        RDFPortal.logger = RDFPortal::Logger.new(repo.working.log_dir.join('statistics.log'))

        action = Interaction::Endpoint::Statistics.run(name:, **config, repository: repo, environment: :stat)

        raise(Error, action.errors.input_error_messages) unless action.valid?
      rescue Error, ActiveInteraction::InvalidInteractionError => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end

      desc 'diff <NAME>', 'Show differences between latest statistics'

      def diff(name)
        config = RDFPortal.endpoint_config(name, :stat)
        repo = repository(name, config)

        unless repo.working.exist?
          abort "Working directory does not exist. Run `rdfportal endpoint setup #{name}`, `rdfportal endpoint load #{name}` and `rdfportal statistics run #{name}` first."
        end

        unless (current = repo.releases.current.stat_dir.join('statistics.yml')).exist?
          abort 'Current statistics file does not exist.'
        end

        unless (working = repo.working.stat_dir.join('statistics.yml')).exist?
          abort 'Working statistics file does not exist.'
        end

        run "diff --side-by-side #{current} #{working}", verbose: false
      rescue Error, ActiveInteraction::InvalidInteractionError => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end

      desc 'publish <NAME>', 'Publish statistics'

      def publish(name)
        config = RDFPortal.endpoint_config(name, :stat)
        repo = repository(name, config)

        unless repo.working.exist?
          abort "Working directory does not exist. Run `rdfportal endpoint setup #{name}`, `rdfportal endpoint load #{name}` and `rdfportal statistics run #{name}` first."
        end

        RDFPortal.logger = RDFPortal::Logger.new(repo.working.log_dir.join('publish.log'))

        action = Interaction::Statistics::Publish.run(name:, **config, repository: repo)

        raise(Error, action.errors.input_error_messages) unless action.valid?
      rescue Error, ActiveInteraction::InvalidInteractionError => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end
    end
  end
end
