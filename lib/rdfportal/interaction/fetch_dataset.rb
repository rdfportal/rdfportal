# frozen_string_literal: true

module RDFPortal
  module Interaction
    class FetchDataset < Base
      include Configurable

      string :name

      string :group, default: nil

      integer :preserve, default: 5

      integer :days_skip_update, default: 5

      array :locations do
        hash strip: false
      end

      boolean :pretend, default: false

      LOG_NAME = 'FETCH DATASET'

      def execute
        RDFPortal.logger.info(LOG_NAME) { "Start #{key.join('.')}" }

        result = Hash.new { |h, k| h[k] = {} }

        t = time do
          break unless pretend || due_for_renewal?

          contents = locations.flat_map.with_index do |location, i|
            RDFPortal.logger.debug(LOG_NAME) { "#{i}: #{location.inspect}" }

            action = ListContents.run(**location)

            unless action.valid?
              e = InvalidConfigurationError.new(action.errors.full_messages.join(', '))
              e.input = { location: }
              raise e
            end

            action.result
          end

          result[key] = contents

          break if pretend

          if dataset_dir.up_to_date?(contents)
            RDFPortal.logger.info(LOG_NAME) { 'All contents are up-to-date' }
            return
          end

          temp_dir = prepare_temp_dir
          copy(contents, temp_dir)
          replace_latest(temp_dir)
          remove_outdated
        end

        RDFPortal.logger.info(LOG_NAME) { "Completed #{key.join('.')} in #{t.to_i.readable_duration}" }

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
