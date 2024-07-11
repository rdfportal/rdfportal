# frozen_string_literal: true

module RDFPortal
  module Interaction
    class FetchDatasets < Base
      include Configurable

      array :datasets do
        hash do
          string :name
        end
      end

      boolean :pretend, default: false

      LOG_NAME = 'FETCH DATASET'

      def execute
        result = {}

        datasets.each do |dataset|
          file = File.join(RDFPortal.config_dir, DATASETS_DIR_NAME, dataset[:name], DATASET_FILE_NAME)

          unless File.exist?(file)
            RDFPortal.logger.info(LOG_NAME) { "Config for #{dataset[:name]} does not exist" }
            next
          end

          config = load_yaml(file)
          if config.keys.length > 1 && config.key?(:'')
            errors.add(:base, 'Blank key are only valid for a single dataset')
            break
          end

          config.each do |group, hash|
            action = FetchDataset.run(hash.merge(name: dataset[:name],
                                                 group: group.presence,
                                                 pretend:))

            unless action.valid?
              e = InvalidConfigurationError.new(action.errors.full_messages.join(', '))
              e.input = { group => hash }
              raise e
            end

            next if action.result.blank?

            result.merge!(action.result)
          rescue InvalidConfigurationError => e
            e.path = file
            raise e
          rescue KeyError => e
            raise ParameterNotDefined, "Parameter definition for `#{e.key}` not found: #{file}"
          end
        end

        result
      end

      private

      def key
        [name, group].compact
      end

      def dataset_dir
        group ? repository.datasets[name][group] : repository.datasets[name]
      end

      def due_for_renewal?
        return true unless dataset_dir.latest.exist?

        RDFPortal.logger.debug(LOG_NAME) { "Found #{dataset_dir.latest.realpath} for latest" }

        latest = Time.parse(File.basename(dataset_dir.latest.realpath)).to_date
        current = Time.now.to_date
        diff = Integer(current - latest).abs

        RDFPortal.logger.debug(LOG_NAME) { "Config.days_skip_update = #{days_skip_update}" }
        RDFPortal.logger.debug(LOG_NAME) { "Days differences = #{diff}" }

        return true if days_skip_update < diff

        RDFPortal.logger.info(LOG_NAME) { 'Skip' }

        false
      end

      def prepare_temp_dir
        return if pretend

        dir = dataset_dir.join('.tmp')
        dir.rmtree if dir.exist?
        dir.mkpath
        dir
      end

      def copy(contents, dir)
        return if pretend

        cache_file = dataset_dir.latest.join(Repository::Dataset::CACHE_FILE_NAME)
        cache = cache_file.exist? ? load_yaml(cache_file) : {}

        contents.each do |content|
          output_path = content.output_path
          src = dataset_dir.latest.join(output_path)
          dest = dir.join(output_path)
          dest.dirname.mkpath

          if src.exist? && (metadata = cache[output_path]).present? && !content.modified?(metadata)
            begin
              # try hard link
              FileUtils.ln(src, dest)
              write_cache(dir, output_path, metadata)

              RDFPortal.logger.debug(LOG_NAME) { "ln #{src} #{dest}" }
            rescue StandardError
              # copy file
              FileUtils.cp(src, dest, preserve: true)
              write_cache(dir, output_path, metadata)

              RDFPortal.logger.debug(LOG_NAME) { "cp #{src} #{dest}" }
            end
          end

          next if dest.exist?

          content.copy_to(dest)
          write_cache(dir, output_path, { mtime: content.mtime, etag: content.etag, md5sum: content.md5sum }.compact)

          RDFPortal.logger.debug(LOG_NAME) { "dl #{src} #{dest}" }
        end
      end

      def write_cache(dir, output_path, metadata)
        return if pretend

        File.open(dir.join(Repository::Dataset::CACHE_FILE_NAME), 'a') do |f|
          f << { output_path => metadata }.deep_transform_keys(&:to_s).to_yaml.sub("---\n", '')
        end
      end

      def replace_latest(dir)
        return if pretend

        latest = dataset_dir.latest
        dataset_dir.latest.unlink if latest.exist?

        dir.rename((current = dataset_dir.join(Time.now.strftime(Repository::Dataset::VERSION_FORMAT))))
        latest.make_symlink(current.relative_path_from(latest.dirname))
      end

      def remove_outdated
        dirs = dataset_dir.glob('*')
                          .filter { |x| x.basename.to_s.match?(Repository::Dataset::VERSION_REGEX) }
                          .sort
                          .reverse
                          .drop(preserve)

        dirs.each do |dir|
          dir.rmtree unless pretend
          RDFPortal.logger.info(LOG_NAME) { "Remove outdated version: #{dir.basename}" }
        end
      end
    end
  end
end
