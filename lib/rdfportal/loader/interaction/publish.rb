# frozen_string_literal: true

require 'rdfportal/loader/interaction'

module RDFPortal
  module Loader
    module Interaction
      class Publish < DatabaseInteraction
        string :release, default: nil

        hash :publish, default: {} do
          array :steps, default: [] do
            hash default: {}, strip: false
          end
        end

        include ExternalCommand

        def execute
          RDFPortal.logger = Store::Base.logger = Logger.new($stdout)

          if work_dir.exist?
            if (dest = repository.endpoints[name].releases.new(release)).exist?
              RDFPortal.logger.warn(PROGRAM_NAME) { "release already exist: #{dest}" }
            else
              src = work_dir.realpath
              RDFPortal::Store::Base.publish(src, dest, **environment)

              if (current = repository.endpoints[name].releases.current).exist?
                current.unlink
              end
              current.make_symlink(dest.relative_path_from(current.dirname))

              RDFPortal.logger = Store::Base.logger = Logger.new(dest.log / 'loader.log')
              RDFPortal.logger.info(PROGRAM_NAME) { "successfully published to #{current}" }
            end
          end

          current = repository.endpoints[name].releases.current
          RDFPortal.logger = Store::Base.logger = Logger.new(current.log / 'publish.log')

          publish[:steps].each do |step|
            case step[:action]
            when 'script'
              unless File.exist?((file = step[:file]))
                RDFPortal.logger.warn(PROGRAM_NAME) { "Script not found: #{file}" }
                next
              end

              env = step[:environments].presence || {}
              env['RDFPORTAL_PUBLISH_ENDPOINT_NAME'] = name
              env['RDFPORTAL_PUBLISH_LATEST_RELEASE'] = current.realpath.to_s

              cmd = File.executable?(file) ? file : "bash #{file}"

              RDFPortal.logger.info(PROGRAM_NAME) { "execute: #{cmd}" }
              RDFPortal.logger.debug(PROGRAM_NAME) { "environments: #{env}" }

              external_command(cmd, stdout: true, stderr: true, log: true, env:) do |out|
                RDFPortal.logger.info(PROGRAM_NAME) { out }
              end
            else
              RDFPortal.logger.warn(PROGRAM_NAME) { "Unknown action: #{step[:action]}" }
            end
          end
        end
      end
    end
  end
end
