# frozen_string_literal: true

module RDFPortal
  module Interaction
    module Endpoint
      require_relative 'base'

      class Publish < Base
        ARRAY_POSTPROCESS_ACTIONS = %w[script].freeze

        validate :postprocess_config

        include ExternalCommand

        def execute
          dest = if repository.working.release_file.exist?
                   repository.releases.new(File.read(repository.working.release_file).strip)
                 else
                   repository.releases.new
                 end

          dest.mkpath unless dest.exist?

          server.publish(dest:)

          if (dir = repository.working.log_dir).exist? && !dir.empty?
            RDFPortal.logger.info(self.class) { 'Copying log files' }
            FileUtils.cp_r(dir, dest, preserve: true)
          end

          if (dir = repository.working.stat_dir).exist? && !dir.empty?
            RDFPortal.logger.info(self.class) { 'Copying statistics files' }
            FileUtils.cp_r(dir, dest, preserve: true)
          end

          if repository.working.cache_file.exist?
            RDFPortal.logger.info(self.class) { 'Copying cache file' }
            FileUtils.cp(repository.working.cache_file, dest, preserve: true)
          end

          File.write(repository.working.release_file, dest.basename.to_s) unless repository.working.release_file.exist?

          publish.dig(:endpoint, :postprocess).each do |hash|
            case hash[:action]
            when 'script'
              env = hash[:environments].presence || {}
              env['RDFPORTAL_PUBLISH_ENDPOINT_NAME'] = name
              env['RDFPORTAL_PUBLISH_LATEST_RELEASE_DIR'] = dest.to_s
              env['RDFPORTAL_PUBLISH_LATEST_RELEASE_VERSION'] = dest.basename.to_s

              cmd = if hash[:file].present?
                      File.executable?(hash[:file]) ? [hash[:file]] : ['sh', hash[:file]]
                    elsif hash[:script].present?
                      hash[:script]
                    else
                      raise Error, '`file` or `script` is required'
                    end

              run_cmd!(*cmd, stdout: :info, stderr: :info, env:)
            else
              raise Error, "Unknown action: #{hash[:action]}"
            end
          end

          current = repository.releases.current

          if current.exist?
            if current.realpath.basename.to_s != dest.basename.to_s
              current.unlink
              current.make_symlink(dest.basename)
            end
          else
            current.make_symlink(dest.basename)
          end

          RDFPortal.logger.info(self.class) { "Successfully published to #{dest}" }

          if (dir = repository.working.log_dir).exist? && !dir.empty?
            # Copy log files at the end
            FileUtils.cp_r(dir, dest, preserve: true)
          end
        end

        private

        def postprocess_config
          return if (postprocess = publish.dig(:endpoint, :postprocess)).blank?

          postprocess.each_with_index do |hash, i|
            attribute = if raw_input(:publish).dig(:endpoint, :postprocess).is_a?(Array)
                          "publish.endpoint.postprocess[#{i}]"
                        else
                          'publish.endpoint.postprocess'
                        end

            unless ARRAY_POSTPROCESS_ACTIONS.include?(hash[:action])
              errors.add("#{attribute}.action", "#{hash[:action]} is invalid")
            end

            next unless hash[:action] == 'script'

            if [hash[:file], hash[:script]].none?(&:present?)
              errors.add(attribute, '`file` or `script` is required')
            elsif ![hash[:file], hash[:script]].one?(&:present?)
              errors.add(attribute, 'either `file` or `script` is required')
            end

            if hash[:file].present?
              hash[:file] = File.expand_path(hash[:file], RDFPortal.config_endpoints_dir)
              errors.add("#{attribute}.file", 'not found') unless File.exist?(hash[:file])
            end
          end
        end
      end
    end
  end
end
