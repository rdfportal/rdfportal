# frozen_string_literal: true

module RDFPortal
  module Interaction
    require_relative '../endpoint/base'

    module Statistics
      class Publish < Endpoint::Base
        ARRAY_POSTPROCESS_ACTIONS = %w[script].freeze

        validate :postprocess_config

        include ExternalCommand

        def execute
          dest = if repository.working.release_file.exist?
                   repository.releases.new(File.read(repository.working.release_file).strip)
                 else
                   raise Error, 'The working endpoint has not published yet'
                 end

          raise Error, "The release #{dest} does not exist" unless dest.exist?

          server.stop!

          if (dir = repository.working.log_dir).exist? && !dir.empty?
            RDFPortal.logger.info(self.class) { 'Copying log files' }
            FileUtils.cp_r(dir, dest, preserve: true)
          end

          if (dir = repository.working.stat_dir).exist? && !dir.empty?
            RDFPortal.logger.info(self.class) { 'Copying statistics files' }
            FileUtils.cp_r(dir, dest, preserve: true)
          end

          publish.dig(:statistics, :postprocess).each do |hash|
            case hash[:action]
            when 'script'
              env = hash[:environments].presence || {}
              env['RDFPORTAL_DATASETS_DIR'] = RDFPortal.datasets_dir.to_s

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

          RDFPortal.logger.info(self.class) { "Successfully published to #{dest}" }

          if (dir = repository.working.log_dir).exist? && !dir.empty?
            # Copy log files at the end
            FileUtils.cp_r(dir, dest, preserve: true)
          end
        end

        private

        def postprocess_config
          return if (postprocess = publish.dig(:statistics, :postprocess)).blank?

          postprocess.each_with_index do |hash, i|
            attribute = if raw_input(:publish).dig(:statistics, :postprocess).is_a?(Array)
                          "publish.statistics.postprocess[#{i}]"
                        else
                          'publish.statistics.postprocess'
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
