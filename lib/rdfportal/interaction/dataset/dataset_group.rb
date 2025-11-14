# frozen_string_literal: true

module RDFPortal
  module Interaction
    module Dataset
      class DatasetGroup < Base
        string :group, default: nil

        integer :preserve, default: nil

        flex_array :fetch, default: nil do
          hash strip: false
        end

        flex_array :postprocess, default: [] do
          hash do
            string :action
            string :script, default: nil
          end
        end

        validates :fetch, presence: true

        validate :fetch_config

        validate :postprocess_config

        attr_reader :directory, :parameters, :continue

        PID_FILE = '.fetch.pid'

        ARRAY_POSTPROCESS_ACTIONS = %w[unzip gunzip untar script].freeze

        REGEX_GZIP_ARCHIVES = /\A.*(?<!\.tar)\.(gz|bgz)\z/
        REGEX_TAR_ARCHIVES = /\A.*\.(tar\.gz|tgz|tar\.bz2|tbz|tbz2|tar\.xz|txz)\z/

        include ExternalCommand

        def initialize(inputs = {})
          raise(Error, 'directory is required') unless (dir = inputs.delete(:directory))

          @directory = Pathname.new(dir)
          @parameters = inputs.delete(:parameters) || {}
          @continue = inputs.delete(:continue)

          super
        end

        # @return [Array<RDFPortal::Result>]
        def execute
          @results = []

          lock do
            next unless pretend || continue || update_required?

            target_dir.mkpath

            RDFPortal.logger.info(self.class) { "Start fetching #{group_name}" } if group

            t = Benchmark.realtime do
              fetch_from_location

              metadata = Repository::Dataset.metadata(target_dir)

              next if pretend || fetch_error_or_empty? || dataset_identical?(metadata)

              post_process

              next if fetch_error_or_empty?

              @results << compose(Update, group:, preserve:, directory:, metadata:)
            end

            RDFPortal.logger.info(self.class) { "Finished fetching #{group_name} in #{t.readable_duration}" } if group
          end

          @results
        ensure
          FileUtils.rm_r(target_dir) if pretend && !continue && target_dir.exist?
        end

        private

        def update_required?
          if target_dir.exist?
            msg = "Dataset already exists: #{group_name}/#{target_dir.basename}"
            RDFPortal.logger.info(self.class) { msg }

            @results << Result.new(:skipped, group_name, msg)

            return false
          end

          if (t = time_since_last_update) && t < 7.days
            msg = "Dataset not yet due for renewal: #{group_name}"
            RDFPortal.logger.info(self.class) { msg }

            @results << Result.new(:skipped, group_name, msg)

            return false
          end

          true
        end

        def fetch_from_location
          pretend_output.puts repository.to_s if pretend

          fetch.each do |hash|
            results = compose(Location, **hash, directory: target_dir, parameters:, continue:, pretend:)
            @results.concat(results)
          end
        rescue StandardError => e
          RDFPortal.logger.error(self.class) { e.full_message }
          @results << Result.new(:error, 'Fetch error', e.message)
        end

        def fetch_error_or_empty?
          if @results.any? { |x| x.failure? || x.error? }
            msg = <<~MSG
              Due to download issues, the latest symlink was not updated.
              Verify the downloaded files, and if there are no issues, execute `rdfportal dataset update #{group_name}`.
            MSG
            @results << Result.new(:failure, 'Latest symlink not updated.', msg)
            return true
          end

          if target_dir.find.none?(&:file?)
            FileUtils.rm_r(target_dir)
            @results << Result.new(:error, 'No files downloaded.')
            return true
          end

          false
        end

        def dataset_identical?(metadata)
          index = repository.index

          return false unless (latest_metadata = index[:metadata])

          RDFPortal.logger.debug(self.class) { "cached metadata = #{latest_metadata}" }
          RDFPortal.logger.debug(self.class) { "current metadata = #{metadata}" }

          return false unless Repository::Dataset.metadata_identical?(latest_metadata, metadata)

          msg = "Datasets are identical with latest data (#{index[:latest]})"
          RDFPortal.logger.info(self.class) { msg }
          FileUtils.rm_r(target_dir)

          @results.clear
          @results << Result.new(:skipped, group_name, msg)

          true
        rescue StandardError => e
          RDFPortal.logger.error(self.class) { e.full_message }
          false
        end

        def post_process
          files = target_dir.find.filter(&:file?).map { |x| x.relative_path_from(target_dir) }

          postprocess.each do |hash|
            @results << send("process_#{hash[:action]}", hash, files)
          end
        rescue StandardError => e
          RDFPortal.logger.error(self.class) { e.full_message }
          @results << Result.new(:error, 'Postprocess error', e.message)
        end

        def group_name
          group ? "#{directory.basename}/#{group}" : directory.basename
        end

        def repository
          @repository ||= if group
                            Repository::Dataset.new(directory.join(group))
                          else
                            Repository::Dataset.new(directory)
                          end
        end

        def target_dir
          @target_dir ||= if continue
                            versions = repository.versions

                            if repository.latest.exist?
                              latest = repository.latest.realpath.basename.to_s
                              if latest.match?(Repository::Dataset::VERSION_REGEX)
                                versions.delete_if { |x| x.basename.to_s <= latest }
                              end
                            end

                            versions.last || raise(Error, 'Continuable dataset not found.')
                          else
                            repository.new_dir
                          end
        end

        def time_since_last_update
          return unless (index = repository.index).present?

          return unless index[:latest].present? && repository.join(index[:latest]).exist?

          return unless index[:updated_at].present? && (updated_at = Time.parse(index[:updated_at]))

          Time.now - updated_at
        rescue StandardError
          nil
        end

        def lock(&)
          return yield if pretend

          if (lock_file = directory.join(PID_FILE)).exist?
            RDFPortal.logger.info(self.class) { 'Another process is fetching. Waiting...' }

            sleep 5 while lock_file.exist?

            RDFPortal.logger.info(self.class) { 'Another process exited.' }
          else
            File.write(lock_file, Process.pid)

            begin
              yield
            ensure
              begin
                lock_file.unlink
              rescue Errno::ENOENT
                # Ignored
              end
            end
          end
        end

        def fetch_config
          return if fetch.blank?

          locations = {}

          fetch.each_with_index do |hash, i|
            locations[i] = (location = Location.new(**hash, directory: target_dir, continue:, pretend:))

            next if location.valid?

            attribute = raw_input(:fetch).is_a?(Array) ? "fetch[#{i}]" : :fetch

            location.errors.each do |error|
              errors.import(error, attribute: "#{attribute}.#{error.attribute}")
            end
          end

          if (recursive = locations.filter { |_, v| v.recursive }).size > 1
            recursive.filter { |_, v| v.output.blank? }.each_key do |k|
              errors.add("fetch[#{k}]", 'recursive location must have output')
            end
          end
        end

        def postprocess_config
          return if postprocess.blank?

          postprocess.each_with_index do |hash, i|
            attribute = raw_input(:postprocess).is_a?(Array) ? "postprocess[#{i}]" : :postprocess

            unless ARRAY_POSTPROCESS_ACTIONS.include?(hash[:action])
              errors.add("#{attribute}.action", "#{hash[:action]} is invalid")
            end

            errors.add("#{attribute}.script", 'is required') if hash[:action] == 'script' && hash[:script].blank?
          end
        end

        def process_unzip(_hash, files)
          RDFPortal.logger.info(self.class) { 'Processing zip files...' }

          files.filter { |x| x.to_s.end_with?('.zip') }.map do |x|
            ret = run_cmd('unzip', x, **postprocess_options)

            Result.new(ret.success? ? :success : :failure, "Extract #{x}", extract_details(ret))
          end
        end

        def process_gunzip(_hash, files)
          RDFPortal.logger.info(self.class) { 'Processing gzip files...' }

          files.filter { |x| REGEX_GZIP_ARCHIVES.match?(x.to_s) }.map do |x|
            ret = run_cmd('gunzip', '--keep', x, **postprocess_options)

            Result.new(ret.success? ? :success : :failure, "Extract #{x}", extract_details(ret))
          end
        end

        def process_untar(_hash, files)
          RDFPortal.logger.info(self.class) { 'Processing tar archives...' }

          files.filter { |x| REGEX_TAR_ARCHIVES.match?(x.to_s) }.map do |x|
            ret = run_cmd('tar', 'xvf', x, **postprocess_options)

            Result.new(ret.success? ? :success : :failure, "Extract #{x}", extract_details(ret))
          end
        end

        def process_script(hash, _files)
          RDFPortal.logger.info(self.class) { 'Processing postprocess script...' }

          ret = run_cmd(hash[:script], **postprocess_options)

          Result.new(ret.success? ? :success : :failure, "Script #{hash[:script]}", extract_details(ret))
        end

        def postprocess_options
          {
            command_log: :info,
            stdout: :info,
            stderr: :info,
            chdir: target_dir
          }
        end
      end
    end
  end
end
