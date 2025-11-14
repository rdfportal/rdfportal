# frozen_string_literal: true

module RDFPortal
  module CLI
    class Dataset < Thor
      class << self
        def exit_on_failure?
          true
        end
      end

      desc 'config <NAME>', 'Parse, resolve and render dataset configuration'

      def config(name)
        interaction = Interaction::Dataset::Fetch.new(**RDFPortal.dataset_config(name), name:)

        raise(Error, interaction.errors.input_error_messages) unless interaction.valid?

        say JSON.pretty_generate(interaction.config)
      rescue Error => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end

      desc 'fetch <NAME>', 'Fetch dataset'
      option :continue, aliases: '-c', type: :boolean, desc: 'Continue getting last failed dataset'
      option :pretend, aliases: '-p', type: :boolean, desc: 'Run but do not fetch actually'

      def fetch(name)
        RDFPortal.logger = RDFPortal::Logger.new($stderr) if RDFPortal.debug? || !options[:pretend]

        action = Interaction::Dataset::Fetch.run(**RDFPortal.dataset_config(name), name:, **options.symbolize_keys)

        raise(Error, action.errors.input_error_messages) unless action.valid?

        say action.result unless options[:pretend]
      rescue Error => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end

      desc 'update <NAME>', 'Update latest dataset'

      def update(name, group: nil)
        name, group = name.split('/', 2) if name.include?('/')

        config = RDFPortal.dataset_config(name)

        directory_prefix = config.dig(:directory, :prefix) || RDFPortal.datasets_dir.join(name).to_s
        preserve = config[:preserve]

        if group.present? && config[:datasets].present?
          unless (c = Array(config[:datasets]).find { |x| x[:group] == group })
            raise(Error, "Group not found: #{name}/#{group}")
          end

          preserve = c[:preserve] if c[:preserve].present?
        end

        action = Interaction::Dataset::Update.run(group:, preserve:, directory_prefix:)

        raise(Error, action.errors.input_error_messages) unless action.valid?

        say action.result
      rescue Error => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end
    end
  end
end
