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

        name, group = name.split('/', 2)

        config = RDFPortal.dataset_config(name)

        config[:datasets] = Array(config[:datasets]).filter { |x| x[:group] == group } if group

        action = Interaction::Dataset::Fetch.run(**config, name:, **options.symbolize_keys)

        raise(Error, action.errors.input_error_messages) unless action.valid?

        say action.result unless options[:pretend]
      rescue Error => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end

      desc 'update <NAME>', 'Update latest dataset'

      def update(name)
        name, group = name.split('/', 2)

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

      desc 'convert <NAME>', 'Convert dataset to ntriples'
      option :output, aliases: '-o', type: :string, required: true, desc: 'Output directory'

      SUPPORTED_COMPRESSION_FORMATS = %w[.gz .bz2 .xz].freeze

      def convert(name)
        RDFPortal.logger = RDFPortal::Logger.new($stderr)

        config = RDFPortal.graph_config(name)

        output_dir = Pathname.new(options[:output])
        files = config.flat_map { |x| Dir.glob(x[:pattern]) }
                      .map { |x| Pathname.new(x).realpath }
                      .sort

        success = []

        files.each do |x|
          dest = output_dir.join(x.relative_path_from(RDFPortal.datasets_dir.realpath)).dirname

          basename = x.basename
          extname = basename.extname
          extname = basename.basename(extname).extname + extname if SUPPORTED_COMPRESSION_FORMATS.include?(extname)

          if dest.join("#{basename.basename(extname)}.nt.gz").exist? ||
             dest.join("#{basename.basename(extname)}.0.nt.gz").exist?
            RDFPortal.logger.info('SKIP') { x.to_s }
            next
          end

          Convert.new.invoke(:ntriples, [x.to_s], force: true, output: dest.to_s, split: true)

          success << x

          RDFPortal.logger.info('SUCCESS') { x.to_s }
        rescue StandardError => e
          RDFPortal.logger.error('FAIL') { "#{x}\n#{e.full_message}" }
        end

        links = success.filter_map do |x|
          dataset, group = x.relative_path_from(RDFPortal.datasets_dir.realpath).each_filename.to_a

          if (latest = RDFPortal.datasets_dir.join(dataset, Repository::Dataset::LATEST_DIR_NAME)).exist?
            [latest.realpath.basename, output_dir.join(name, Repository::Dataset::LATEST_DIR_NAME)]
          elsif (latest = RDFPortal.datasets_dir.join(dataset, group, Repository::Dataset::LATEST_DIR_NAME)).exist?
            [latest.realpath.basename, output_dir.join(name, group, Repository::Dataset::LATEST_DIR_NAME)]
          end
        end

        links.uniq.each do |from, to|
          FileUtils.rm_f(to)
          FileUtils.ln_s(from, to)
        end
      rescue Error => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end
    end
  end
end
