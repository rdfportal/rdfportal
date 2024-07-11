# frozen_string_literal: true

require 'digest/md5'
require 'pathname'
require 'tempfile'

module RDFPortal
  module Dataset
    class Content
      class HTTPContent < Content
        LOG_NAME = 'HTTP CONTENT'

        def initialize(uri, type, **options)
          @temp_file = nil
          super
        end

        def meta
          @meta ||= {
            mime_type: headers['content-type'],
            size: Integer(headers['content-length'], exception: false),
            etag: headers['etag'],
            mtime: begin
                     Time.parse(headers['last-modified'])
                   rescue StandardError
                     nil
                   end
          }.compact
        end

        def output_file_name
          return @options[:output_file_name] if @options[:output_file_name].present?

          file_name = if (v = headers['content-disposition']).present? && (m = v.match(/filename="([^"]+)"/))
                        name = m[1]
                        # workaround for BioPortal
                        name.sub!('.xrdf', '.xml') if name.end_with?('.xrdf')
                        name
                      else
                        super
                      end

          @options[:output_file_name] = file_name
        end

        def md5sum
          return if directory?

          return unless (file = temp_file)

          @md5sum ||= Digest::MD5.file(file).hexdigest
        end

        def copy_to(dest)
          return if directory?

          return unless (file = temp_file)

          dest = File.join(dest, File.basename(file)) if File.directory?(dest)

          raise DirectoryNotFound, File.dirname(dest) unless Dir.exist?(File.dirname(dest))

          FileUtils.cp(file, dest)
          FileUtils.touch(dest, mtime:, nocreate: true) if mtime.present?
        end

        private

        def http_opts
          { followlocation: true }.merge(Hash(@options[:http]))
        end

        def headers
          return {} if directory?

          unless (res = Typhoeus.head(@uri, **http_opts)).success?
            raise HTTPRequestError, res
          end

          @headers ||= res.headers.transform_keys(&:downcase)
        end

        def temp_file
          return if directory?

          return @temp_file if @temp_file.present? && File.exist?(@temp_file)

          file = Tempfile.new

          RDFPortal.logger.info(LOG_NAME) { "Downloading #{@uri} #{http_opts}" }
          download(file, @uri, **http_opts)

          @temp_file = file.path

          ObjectSpace.define_finalizer(@temp_file, proc {
            next unless @temp_file && File.exist?(@temp_file)

            FileUtils.rm(@temp_file)
            RDFPortal.logger.debug(LOG_NAME) { "Clean up #{@temp_file}" }
          })

          @temp_file
        end

        # @param [File] file
        # @param [URI] url
        # @param [Hash] options
        def download(file, url, **options)
          request = Typhoeus::Request.new(url, **options)

          request.on_body do |chunk|
            file.write(chunk)
          end

          request.on_complete do |response|
            file.close
            @headers ||= response.headers.with_indifferent_access
          end

          request.on_failure do |response|
            raise HTTPRequestError, response
          end

          request.run
        end
      end
    end
  end
end
