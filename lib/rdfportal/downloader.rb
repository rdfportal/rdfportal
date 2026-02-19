# frozen_string_literal: true

module RDFPortal
  require 'rdfportal/external_command'

  class Downloader
    attr_reader :url, :output, :recursive, :include, :exclude, :options, :pretend, :pretend_output

    include ExternalCommand

    def initialize(url:, output:, recursive:, include: [], exclude: [], **options)
      @url = url
      @output = output
      @recursive = recursive
      @include = include
      @exclude = exclude
      @pretend = options.delete(:pretend)
      @pretend_output = options.delete(:pretend_output)
      @options = options
    end

    def wget
      uri = URI(url)

      cmd = ['wget']
      cmd << '--no-verbose'

      cmd << '--no-check-certificate' if options.key?(:verify_certificate) && !options[:verify_certificate]

      if (v = options.dig(:header, :accept))
        cmd << '--header'
        cmd << "Accept:#{v}"
      end

      if output
        cmd << '--output-document'
        cmd << output
      else
        cmd << '--timestamping' unless recursive
      end

      cmd << '--content-disposition' if options[:content_disposition]
      cmd << '--continue' if options[:continue]

      if recursive
        cmd << '--recursive'
        cmd << '--no-parent'

        if (v = options.dig(:recursive, :level))&.positive?
          cmd << "--level=#{v}"
        end

        cmd << '--no-host-directories'

        if (depth = uri.path.split('/').compact_blank.size).positive?
          cmd << "--cut-dirs=#{depth}"
        end

        if (v = options.dig(:recursive, :output))
          cmd << '--directory-prefix'
          cmd << v
        end

        if include.present?
          cmd << '--accept'
          cmd << include.join(',')
        end

        if exclude.present?
          cmd << '--reject'
          cmd << exclude.join(',')
        end

        if (v = Array(options.dig(:recursive, :include_directories))).present?
          cmd << '--include-directories'
          cmd << v.join(',')
        end

        if (v = Array(options.dig(:recursive, :exclude_directories))).present?
          cmd << '--exclude-directories'
          cmd << v.join(',')
        end

        uri.path += '/' unless url.end_with?('/')
      end

      cmd << uri.to_s

      ret = if pretend
              pretend_output&.with_indent do |out|
                out.puts("* #{cmd_string(*cmd)}")

                out.with_indent do
                  cmd.insert(1, '--spider')

                  run_cmd(*cmd,
                          stdout: out,
                          stderr: out,
                          format: ->(str) { str.gsub(%r{\A.*(https?://)}, '\1') },
                          chdir: options[:directory])
                end
              end
            else
              prepare_directory

              unless recursive
                link_latest unless options[:continue]

                # `wget` does not support timestamp check with `--output-document` option,
                # so check the timestamp manually
                if output && content_not_modified?(url, output)
                  RDFPortal.logger.info(self.class) { 'Not modified on server, omitting download.' }
                  return
                end
              end

              run_cmd(*cmd, stdout: :info, stderr: :info, chdir: options[:directory])
            end

      RDFPortal.logger.warn(self.class) { extract_details(ret) } unless ret.success?

      Result.new(ret.success? ? :success : :failure, "Fetch #{uri}", extract_details(ret))
    end

    def lftp
      uri = URI(url)

      open = ['open']

      if (user = options[:user])
        open << '--user'
        open << user
      end

      if (password = options[:password])
        open << '--password'
        open << password
      end

      if (port = options[:port])
        open << '-p'
        open << port
      end

      open << "#{uri.scheme}://#{uri.host}"

      mirror = ['mirror']
      mirror << '--verbose'
      mirror << '--only-newer'

      mirror << '--continue' if options[:continue]

      if recursive
        mirror << '--delete'

        if (v = options[:parallel]) && v.to_i.positive?
          mirror << "--parallel=#{v}"
        end

        if include.present?
          Array(include).each do |pattern|
            mirror << '--include-glob'
            mirror << pattern
          end
        end

        if exclude.present?
          Array(exclude).each do |pattern|
            mirror << '--exclude-glob'
            mirror << pattern
          end
        end

        if (v = options.dig(:mirror, :include_regex)).present?
          Array(v).each do |pattern|
            mirror << '--include'
            mirror << pattern
          end
        end

        if (v = options.dig(:mirror, :exclude_regex)).present?
          Array(v).each do |pattern|
            mirror << '--exclude'
            mirror << pattern
          end
        end

        uri.path += '/' unless url.end_with?('/')

        mirror << uri.path
      else
        mirror << '--no-recursion'
        mirror << '--include'
        mirror << File.basename(uri.path)
        mirror << "#{File.dirname(uri.path)}/"
      end

      mirror << output.present? ? "./#{output}" : '.'

      ret = if pretend
              pretend_output&.with_indent do |out|
                out.puts("* #{cmd_string(*lftp_command(open, mirror))}")

                out.with_indent do
                  mirror.insert(1, '--dry-run')

                  run_cmd(*lftp_command(open, mirror),
                          stdout: pretend_output,
                          stderr: pretend_output,
                          chdir: options[:directory])
                end
              end
            else
              prepare_directory
              link_latest unless options[:continue]
              run_cmd(*lftp_command(open, mirror), stdout: :info, stderr: :info, chdir: options[:directory])
            end

      RDFPortal.logger.warn(self.class) { extract_details(ret) } unless ret.success?

      Result.new(ret.success? ? :success : :failure, "Fetch #{uri}", extract_details(ret))
    end

    def rsync
      uri = URI(url)

      cmd = ['rsync']
      cmd << '--verbose'
      cmd << '--human-readable'
      cmd << '--links'
      cmd << '--perms'
      cmd << '--times'

      if recursive
        cmd << '--recursive'
        cmd << '--update'
        cmd << '--delete'

        uri.path += '/' unless url.end_with?('/')
      end

      cmd << '--partial' if options[:continue]

      if include.present?
        Array(include).each do |pattern|
          cmd << '--include'
          cmd << pattern
        end
      end

      if exclude.present?
        Array(exclude).each do |pattern|
          cmd << '--exclude'
          cmd << pattern
        end
      end

      cmd << if uri.scheme == 'rsync'
               "#{uri.host}::#{uri.path.delete_prefix('/')}"
             elsif (host = options.dig(:ssh, :host))
               program = ['ssh']

               if (port = options.dig(:ssh, :port))
                 program << '-p'
                 program << port
               end

               program << '-o'
               program << "'StrictHostKeyChecking no'"

               cmd << '-e'
               cmd << program.join(' ')

               if (user = options.dig(:ssh, :user))
                 "#{user}@#{host}:#{uri.path}"
               else
                 "#{host}:#{uri.path}"
               end
             else
               uri.path
             end

      cmd << output.present? ? "./#{output}" : '.'

      ret = if pretend
              pretend_output&.with_indent do |out|
                out.puts("* #{cmd_string(*cmd)}")

                out.with_indent do
                  cmd.insert(1, '--dry-run') if pretend

                  run_cmd(*cmd, stdout: pretend_output, stderr: pretend_output, chdir: options[:directory])
                end
              end
            else
              prepare_directory
              link_latest unless options[:continue]
              run_cmd(*cmd, stdout: :info, stderr: :info, chdir: options[:directory])
            end

      RDFPortal.logger.warn(self.class) { extract_details(ret) } unless ret.success?

      Result.new(ret.success? ? :success : :failure, "Fetch #{uri}", extract_details(ret))
    end

    private

    def prepare_directory
      return unless output

      Pathname.new(options[:directory] || '.').join(output).dirname.mkpath
    end

    def lftp_command(open, mirror)
      settings = []
      settings << 'ssl:verify-certificate no' if options.key?(:verify_certificate) && !options[:verify_certificate]

      if (v = options[:ftp_settings])
        settings.concat(Array(v))
      end

      ftp_command = settings.uniq.map do |setting|
        "set #{setting}"
      end

      ftp_command << open.join(' ')
      ftp_command << mirror.join(' ')
      # If the remote directory ends with / (e.g., /path/to/remote/),
      #   lftp does not make the directory and copies files into the current directory.
      # If not (e.g., /path/to/remote),
      #   lftp makes the "remote" directory in the current directory and copies files into the "remote" directory.

      cmd = ['lftp']
      cmd << '-c'
      cmd << ftp_command.join('; ')

      cmd
    end

    def content_not_modified?(url, local)
      return false unless File.exist?(local)

      last_modified = Resource::HTTP.last_modified(url)

      return false if last_modified && File.mtime(local) < last_modified

      true
    end

    def link_latest
      return unless options[:directory]
      return unless (target_dir = Pathname.new(options[:directory])).exist?
      return unless (latest = target_dir.dirname.join('latest')).exist?

      src, dest = if recursive
                    if output
                      [latest.realpath.join(output), target_dir.join(output)]
                    else
                      [latest.realpath, target_dir]
                    end
                  elsif output
                    [latest.realpath.join(output), target_dir.join(output)]
                  else
                    [latest.realpath.join(File.basename(URI(url).path)), target_dir]
                  end

      return unless src.exist?

      Repository::Dataset.link_tree(src, dest)
    end
  end
end
