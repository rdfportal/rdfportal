# frozen_string_literal: true

module RDFPortal
  module Dataset
    class Location
      class FTPLocation < Location
        include FTPClient

        LOG_NAME = 'FTP LOCATION'

        protected

        def join(other)
          class << other
            def typecode; end
          end
          URI.join(@uri, other)
        end

        def list_contents(directory: true, file: true)
          client.mlsd(@uri.path).filter_map do |x|
            options = @options.merge(meta: {
              size: x.size,
              mtime: x.modify
            }.compact)

            case x.facts['type']
            when 'dir'
              name = x.pathname.end_with?('/') ? x.pathname : "#{x.pathname}/"
              Content::FTPContent.new(join(name), Content::TYPE::DIRECTORY, **options) if directory
            when 'file'
              Content::FTPContent.new(join(x.pathname), Content::TYPE::FILE, **options) if file
            else
              false
            end
          end
        rescue Net::FTPTempError => e
          raise e if @retry_count >= 3

          @client = @options[:ftp_client] = nil
          @retry_count += 1
          retry
        rescue Net::FTPPermError
          client.nlst(path).map do |x|
            meta = {
              size: begin
                      client.size(x)
                    rescue Net::FTPPermError
                      nil
                    end,
              mtime: begin
                       client.mtime(x)
                     rescue Net::FTPPermError
                       nil
                     end
            }.compact

            FTPContent.new(join(File.basename(x)), meta[:size] ? Content::TYPE::FILE : Content::TYPE::DIRECTORY, meta)
          end
        end

        def entries(path)
          client.mlsd(path)
        rescue Net::FTPPermError
          # MLSD command is not supported
          client.nlst(path).map do |x|
            size = begin
                     client.size(x)
                   rescue Net::FTPPermError
                     nil
                   end
            modify = begin
                       client.mtime(x)
                     rescue Net::FTPPermError
                       nil
                     end
            facts = {
              'size' => size,
              'modify' => modify,
              'type' => size ? 'file' : 'dir'
            }.compact

            # return compatible object
            Net::FTP::MLSxEntry.new(facts, File.basename(x))
          end
        end

        def client
          @client ||= ftp_client(@uri, **@options)
        end
      end
    end
  end
end
