# frozen_string_literal: true

require 'nokogiri'
require 'typhoeus'

module RDFPortal
  class RemoteDirectory
    include ExternalCommand

    module Type
      DIRECTORY = :directory
      FILE = :file
    end

    class << self
      def parse(uri)
        case URI(uri.to_s)
        when URI::HTTP
          HTTP.new(uri)
        when URI::FTP
          FTP.new(uri)
        else
          raise ArgumentError, "Unsupported URL: #{uri}"
        end
      end

      protected :new
    end

    attr_reader :uri

    def initialize(uri)
      @uri = URI(uri)
    end
  end

  class Entry
    attr_reader :uri, :type

    def initialize(uri, type)
      @uri = uri
      @type = type
    end

    def basename
      File.basename(uri.path)
    end

    def dirname
      File.dirname(uri.path)
    end
  end

  class HTTP < RemoteDirectory
    class << self
      def last_modified(uri, **options)
        http_opts = { followlocation: true }.merge(Hash(options[:http]))

        res = Typhoeus.head(uri, **http_opts)

        Time.parse(res.headers['last-modified'])
      rescue StandardError
        nil
      end
    end

    def list(**options)
      http_opts = { followlocation: true, headers: { accept: 'text/html' } }.merge(Hash(options[:http]))

      res = Typhoeus.get(uri, **http_opts)
      effective_url = URI(res.effective_url)

      Nokogiri::HTML.parse(res.response_body, options[:encoding]).xpath('/html/body//a[@href]').filter_map do |elem|
        entry = URI.join(effective_url, elem[:href])

        next unless entry.host == effective_url.host
        next unless entry.path.to_s.match?(Regexp.new("^#{effective_url.path}.+"))
        next unless (m = entry.path.to_s.delete_prefix(effective_url.path.to_s).match(%r{[^/]+/?}))

        if m[0].end_with?('/')
          Entry.new(entry, Type::DIRECTORY)
        else
          Entry.new(entry, Type::FILE)
        end
      end
    end
  end

  class FTP < RemoteDirectory
    def list(**options)
      cmd = ['lftp']

      if (port = options.dig(:ftp, :port))
        cmd << '--port'
        cmd << port
      end

      if (user = options.dig(:ftp, :user))
        cmd << '--user'
        cmd << (pass = options.dig(:ftp, :pass)) ? "#{user},#{pass}" : user
      end

      cmd << '-e'
      cmd << "cd '#{uri.path}'; cls -1D; bye"
      cmd << uri.host

      ret = run_cmd(*cmd)

      raise ExternalCommandError, ret if ret.failure?

      ret.out.split(/\R/).map do |x|
        x.sub!(/@$/, '') # remove symbolic link suffix
        entry = uri.dup
        entry.path = Pathname.new(uri.path).join(Pathname.new(x)).to_s

        if entry.to_s.match?(%r{/$})
          Entry.new(entry, Type::DIRECTORY)
        else
          Entry.new(entry, Type::FILE)
        end
      end
    end
  end
end
