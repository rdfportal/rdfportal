# frozen_string_literal: true

require 'digest/md5'
require 'pathname'
require 'tmpdir'

module RDFPortal
  module Dataset
    class Content
      class FTPContent < Content
        include FTPClient

        LOG_NAME = 'FTP CONTENT'

        attr_reader :meta

        def initialize(uri, type, **options)
          @meta = options[:meta]
          super
        end

        def md5sum
          return if directory?

          return unless (file = temp_file)

          @md5sum ||= Digest::MD5.file(file).hexdigest
        end

        protected

        def temp_file
          @temp_file ||= begin
                           FileUtils.mkdir_p((tmpdir = File.join(Dir.tmpdir, 'rdfportal', @uri.host)))

                           ObjectSpace.define_finalizer(tmpdir, proc {
                             next unless tmpdir && File.exist?(tmpdir)

                             FileUtils.rm_rf(tmpdir)
                             RDFPortal.logger.debug(LOG_NAME) { "Clean up #{tmpdir}" }
                           })

                           File.join(tmpdir, File.basename(@uri.path)).tap do |file|
                             RDFPortal.logger.info(LOG_NAME) { "Downloading #{@uri}" }
                             client.get(@uri.path, file)
                           end
                         end
        end

        private

        def client
          @client ||= ftp_client(@uri, **@options)
        end
      end
    end
  end
end
