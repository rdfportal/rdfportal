# frozen_string_literal: true

module RDFPortal
  module CLI
    require_relative 'base'

    class Dataset < Base
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
      option :no_incremental, aliases: '-I', type: :boolean, desc: 'Do not use incremental fetching'
      option :pretend, aliases: '-p', type: :boolean, desc: 'Run but do not fetch actually'

      def fetch(name)
        RDFPortal.logger = RDFPortal::Logger.new(if RDFPortal.debug? || options[:pretend]
                                                   $stderr
                                                 else
                                                   RDFPortal.log_dir
                                                            .join('fetch', with_datetime_prefix("#{name}.log"))
                                                            .tap { |x| x.dirname.mkpath }
                                                 end)

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
      option :max_procs, aliases: '-P', type: :numeric, default: 1, desc: 'Maximum number of parallel processes'

      SUPPORTED_COMPRESSION_FORMATS = %w[.gz .bz2 .xz].freeze

      def convert(name)
        require 'parallel'

        RDFPortal.logger = RDFPortal::Logger.new($stderr)

        max_procs = (options[:max_procs] || 1).to_i
        unless (1..Parallel.processor_count).cover?(max_procs)
          raise Error, "Invalid max_procs: #{max_procs} (must be between 1 and #{Parallel.processor_count})"
        end

        files = RDFPortal.graph_config(name).flat_map { |x| Dir.glob(x[:pattern]) }
                         .map { |x| Pathname.new(x).realpath }
                         .sort

        output_dir = Pathname.new(options[:output])

        success = Parallel.filter_map(files, in_processes: max_procs) do |file|
          dest = output_dir.join(file.relative_path_from(RDFPortal.datasets_dir.realpath)).dirname

          basename = file.basename
          extname = basename.extname
          extname = basename.basename(extname).extname + extname if SUPPORTED_COMPRESSION_FORMATS.include?(extname)

          if dest.join("#{basename.basename(extname)}.nt.gz").exist? ||
             dest.join("#{basename.basename(extname)}.0.nt.gz").exist?
            RDFPortal.logger.info('SKIP') { file.to_s }
            next
          end

          Convert.new.invoke(:ntriples, [file.to_s], force: true, output: dest.to_s, split: true)

          RDFPortal.logger.info('SUCCESS') { file.to_s }
          file
        rescue StandardError => e
          RDFPortal.logger.error('FAIL') { "#{file}\n#{e.full_message}" }
          nil
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
