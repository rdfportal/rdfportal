# frozen_string_literal: true

require 'digest/md5'
require 'pathname'
require 'tmpdir'

module RDFPortal
  module Dataset
    class Content
      LOG_NAME = 'CONTENT'

      # content uri (one of file://, ftp://, http:// or https://)
      attr_reader :uri
      # :file or :directory
      attr_reader :type

      module TYPE
        DIRECTORY = :directory
        FILE = :file
      end

      def initialize(uri, type, **options)
        @uri = URI(uri.to_s)
        @type = type
        @options = options

        yield self if block_given?
      end

      def file?
        type == TYPE::FILE
      end

      def directory?
        type == TYPE::DIRECTORY
      end

      def basename
        File.basename(@uri.path)
      end

      def dirname
        File.dirname(@uri.path)
      end

      # @return [String]
      def output_path
        if (path = @options[:output_base_path]).present?
          Pathname.new(path).join(output_file_name).to_s
        else
          output_file_name
        end
      end

      def output_file_name
        @options[:output_file_name].presence || basename
      end

      def meta
        raise NotImplementedError
      end

      def size
        meta[:size]
      end

      def mtime
        safe_parse_time(meta[:mtime])
      end

      def etag
        meta[:etag]
      end

      def md5sum
        raise NotImplementedError
      end

      def modified?(metadata)
        if (t1 = safe_parse_time(metadata[:mtime])) && (t2 = mtime)
          RDFPortal.logger.debug(LOG_NAME) { "Modified time of current = #{t2}, cache = #{t1}" }
          return false if t1 == t2
        end

        if metadata[:etag] && etag
          RDFPortal.logger.debug(LOG_NAME) { "Etag of current = #{etag}, cache = #{metadata[:etag]}" }
          return false if metadata[:etag] == etag
        end

        if metadata[:md5sum] && md5sum
          RDFPortal.logger.debug(LOG_NAME) { "MD5sum of current = #{md5sum}, cache = #{metadata[:md5sum]}" }
          return false if metadata[:md5sum] == md5sum
        end

        true
      end

      def copy_to(dest)
        return if directory?

        return unless (file = temp_file)

        dest = File.join(dest, File.basename(file)) if File.directory?(dest)

        raise DirectoryNotFound, File.dirname(dest) unless Dir.exist?(File.dirname(dest))

        FileUtils.cp(file, dest)
        FileUtils.touch(dest, mtime:, nocreate: true) if mtime.present?
      end

      protected

      def temp_file
        raise NotImplementedError
      end

      def safe_parse_time(value)
        return value.getutc if value.is_a?(Time)
        return value.to_time.getutc if value.is_a?(Date)

        Time.parse(value).getutc
      rescue StandardError
        nil
      end
    end

    require 'rdfportal/dataset/content/http_content'
    require 'rdfportal/dataset/content/ftp_content'
  end
end
