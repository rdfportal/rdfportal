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
          current = repository.releases.current

          if (dest = repository.releases.new).exist?
            RDFPortal.logger.warn(self.class) { "Release already exist: #{dest}" }
          else
            dest.mkpath

            server.publish(dest:)

            current.unlink if current.exist?

            current.make_symlink(dest.basename)

            RDFPortal.logger.info(self.class) { "Successfully published to #{dest}" }
          end

          publish[:postprocess].each do |step|
            case step[:action]
            when 'script'
              env = step[:environments].presence || {}
              env['RDFPORTAL_PUBLISH_ENDPOINT_NAME'] = name
              env['RDFPORTAL_PUBLISH_LATEST_RELEASE'] = dest.to_s

              cmd = if (file = step[:file]).present?
                      File.executable?(file) ? [file] : ['sh', file]
                    elsif step[:script].present?
                      step[:script]
                    else
                      raise Error, '`file` or `script` is required'
                    end

              run_cmd!(cmd, stdout: :info, stderr: :info, env:)
            else
              raise Error, "Unknown action: #{step[:action]}"
            end
          end
        end

        private

        def postprocess_config
          return if publish[:postprocess].blank?

          publish[:postprocess].each_with_index do |hash, i|
            attribute = raw_input(:publish)[:postprocess].is_a?(Array) ? "publish.postprocess[#{i}]" : 'publish.postprocess'

            unless ARRAY_POSTPROCESS_ACTIONS.include?(hash[:action])
              errors.add("#{attribute}.action", "#{hash[:action]} is invalid")
            end

            next unless hash[:action] == 'script'

            if [hash[:file], hash[:script]].none?(&:present?)
              errors.add(attribute, '`file` or `script` is required')
            elsif ![hash[:file], hash[:script]].one?(&:present?)
              errors.add(attribute, 'either `file` or `script` is required')
            end

            errors.add("#{attribute}.file", 'not found') if hash[:file].present? && !File.exist?(hash[:file])
          end
        end
      end
    end
  end
end
