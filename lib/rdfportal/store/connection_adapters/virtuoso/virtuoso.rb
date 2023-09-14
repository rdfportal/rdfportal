# frozen_string_literal: true

require 'benchmark'
require 'fileutils'
require 'inifile'
require 'pathname'

module RDFPortal
  module Store
    module ConnectionAdapters
      class Virtuoso
        include Util::ExternalCommand

        class InsufficientConfiguration < Error; end

        class NoAvailablePorts < Error; end

        class LockFileNotFound < Error; end

        INIFILE = 'inifile'
        VIRTUOSO_T = 'virtuoso-t'
        ISQL = 'isql'

        def initialize(**config)
          raise(InsufficientConfiguration, 'ini') unless config[:ini].present?

          @config = config
          @virtuoso_ini = Pathname.new(config[:ini])
        end

        def connect(**options)
          Connection.new(**options.merge(bin: bin(ISQL)))
        end

        def init
          if ini_file.exist?
            Base.logger.info(PROGRAM_NAME) { 'configure ini file from environment' }
            ini_from_env
          else
            Base.logger.info(PROGRAM_NAME) { "copy template ini to #{ini_file}" }
            copy_ini_template

            Base.logger.info(PROGRAM_NAME) { 'configure ini file from environment' }
            ini_from_env

            Base.logger.info(PROGRAM_NAME) { 'create initial database' }
            create_initial_database

            if @config.key?(:password)
              Base.logger.info(PROGRAM_NAME) { 'set dba password' }
              set_password
            end
          end
        end

        def start
          Base.logger.info(PROGRAM_NAME) { 'starting server' }

          raise FileNotFound, ini_file.to_s unless ini_file.exist?

          status = external_command(bin(VIRTUOSO_T), '+configfile', ini_file.to_s)

          return unless status.success?

          loop do
            break if running?

            sleep 1
          end

          Base.logger.info(PROGRAM_NAME) { "HTTP/WebDAV server started at #{http_port}" }
          Base.logger.info(PROGRAM_NAME) { "server started at #{isql_port}" }
        end

        def stop
          Base.logger.info(PROGRAM_NAME) { 'stopping server' }

          raise LockFileNotFound, lock_file unless File.exist?(lock_file)

          return unless (pid = File.read(lock_file.to_s).match(/=(\d+)/)&.captures&.first)

          external_command('kill', '-INT', pid.to_s)

          loop do
            break unless running?

            sleep 1
          end

          Base.logger.info(PROGRAM_NAME) { 'server stopped' }
        end

        def snapshot(destination)
          if (running = running?)
            Base.logger.info(PROGRAM_NAME) { 'stopping server before taking snapshot' }
            stop
          end

          time = Benchmark.realtime do
            FileUtils.cp database_file, destination
          end

          Base.logger.info(PROGRAM_NAME) do
            "successfully saved snapshot to #{destination}: #{time.to_i.readable_duration}"
          end

          return unless running

          Base.logger.info(PROGRAM_NAME) { 'restarting server' }
          start
        end

        def restore(source)
          if running?
            Base.logger.info(PROGRAM_NAME) { 'stopping server before restoring from snapshot' }
            stop
          end

          time = Benchmark.realtime do
            FileUtils.cp source, database_file
          end
          Base.logger.info(PROGRAM_NAME) do
            "successfully restored snapshot from #{source}: #{time.to_i.readable_duration}"
          end

          Base.logger.info(PROGRAM_NAME) { 'starting server' }
          start
        end

        def running?
          return false unless ini_file.exist?

          Port.listen?(isql_port).tap do |bool|
            Base.logger.debug(PROGRAM_NAME) { "port #{isql_port} listening: #{bool}" }
          end
        end

        # @return [Integer]
        def isql_port
          Integer(settings[:Parameters][:ServerPort])
        end

        # @return [Integer]
        def http_port
          Integer(settings[:HTTPServer][:ServerPort])
        end

        private

        def options
          @config[:options] || {}
        end

        def copy_ini_template
          src = options[:ini_template] || raise(InsufficientConfiguration, 'ini_template')
          dir = ini_file.dirname

          FileUtils.mkdir_p(dir)
          FileUtils.cp(src, ini_file)
        end

        def ini_from_env
          @config[:environment]&.each do |section, settings|
            settings.each do |key, value|
              if key == 'ServerPort' && value.is_a?(String) && (m = value.match(/(\d+)\.+(\d+)/))
                port = (m[1].to_i..m[2].to_i).find { |n| !Port.listen?(n) }
                raise NoAvailablePorts, value if port.nil?

                Base.logger.debug(PROGRAM_NAME) { "port #{port} is available" }
                value = port
              end

              cmd = [bin(INIFILE),
                     '+inifile', ini_file.to_s,
                     '+section', section,
                     '+key', key,
                     '+value', value.to_s]

              external_command(*cmd) { |out| Base.logger.debug(PROGRAM_NAME) { out } }
            end
          end
        end

        def create_initial_database
          cmd = [bin(VIRTUOSO_T),
                 '+foreground',
                 '+checkpoint-only',
                 '+configfile', ini_file.to_s]

          external_command(*cmd) { |out| Base.logger.debug(PROGRAM_NAME) { out } }
        end

        def set_password
          cmd = [bin(VIRTUOSO_T),
                 '+foreground',
                 '+checkpoint-only',
                 '+configfile', ini_file.to_s,
                 '+pwdold', 'dba',
                 '+pwddba', @config[:password],
                 '+pwddav', @config[:password]]

          external_command(*cmd, log: false) { |out| Base.logger.debug(PROGRAM_NAME) { out } }
        end

        def bin(command)
          options[:bin] ? (Pathname.new(options[:bin]) / command).to_s : command
        end

        # @return [Pathname]
        def ini_file
          @virtuoso_ini
        end

        def settings
          @settings ||= IniFile.load(ini_file).to_h.with_indifferent_access
        end

        # @return [Pathname]
        def database_file
          Pathname.new(settings[:Database][:DatabaseFile])
        end

        # @return [Pathname]
        def lock_file
          Pathname.new(settings[:Database][:LockFile])
        end
      end
    end
  end
end
