# frozen_string_literal: true

module RDFPortal
  module Dataset
    class Location
      class << self
        # @return [RDFPortal::Dataset::Location]
        def open(uri, **options)
          uri = "#{uri}/" if !uri.to_s.end_with?('/') && options[:recursive]

          loc = case uri.to_s
                when %r{^https?://}
                  HTTPLocation.new(uri, **options)
                when %r{^ftp://}
                  FTPLocation.new(uri, **options)
                when %r{^/}
                  LocalLocation.new(uri, **options)
                else
                  raise ArgumentError, "Unsupported location specifier: #{uri}"
                end

          yield loc if block_given?

          loc
        end
      end

      attr_reader :uri

      # @param [Hash] options
      # @option options [Boolean] :recursive
      # @option options [Array<String>] :includes
      def initialize(uri, **options)
        @uri = URI(uri)
        @options = options

        @options[:remote_root_path] ||= @uri.path
      end

      # @return [Array<RDFPortal::Dataset::Content>]
      def list(directory: true, file: true)
        return @list if @list.present?

        list = []

        directories, files = list_contents.partition(&:directory?)
        list.concat(directories) if directory
        list.concat(files) if file

        if @options[:recursive]
          directories.each do |x|
            list.concat(self.class.new(join(x.basename), **@options).list(directory:, file:))
          end
        end

        @list = list
      end

      protected

      def join(other)
        URI.join(@uri, other)
      end

      def relative_path(uri)
        path = URI(@options[:remote_root_path]).path.presence || '/'

        Pathname.new(uri.path).relative_path_from(Pathname.new(path)).to_s
      end

      # @return [Array<RDFPortal::Dataset::Content>]
      def list_contents(directory: true, file: true)
        raise NotImplementedError
      end
    end

    require 'rdfportal/dataset/location/ftp_location'
    require 'rdfportal/dataset/location/http_location'
  end
end
