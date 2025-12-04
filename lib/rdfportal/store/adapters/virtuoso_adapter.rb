# frozen_string_literal: true

module RDFPortal
  module Store
    require 'rdfportal/store/abstract_adapter'

    module Adapters
      class VirtuosoAdapter < AbstractAdapter
        require 'rdfportal/store/adapters/virtuoso_adapter/connection'
        require 'rdfportal/store/adapters/virtuoso_adapter/executable'
        require 'rdfportal/store/adapters/virtuoso_adapter/statistics'

        READY_TIMEOUT = 5 * 60

        class << self
          # @param [String] name Endpoint name
          # @param [Hash] options
          # @option options [Pathname] :database database options and settings
          # @option options [Pathname] :repository
          def create(name, **options)
            host = options.dig(:database, :host) || 'localhost'
            port = options.dig(:database, :settings, :Parameters, :ServerPort)
            user = options.dig(:database, :user) || 'dba'
            password = options.dig(:database, :password) || RDFPortal.virtuoso_password

            new(name, options[:repository],
                database: options[:database],
                environment: options.fetch(:environment, Environment::LOAD),
                datasets: options[:datasets],
                load: options[:load],
                stat: options[:stat],
                host:,
                port:,
                user:,
                password:)
          end
        end

        def server_running?(connect_timeout: 1.0)
          running_by_pidfile? && running_by_socket?(connect_timeout:)
        end

        def start_if_needed!
          return true if running_by_pidfile?

          RDFPortal.logger.info(self.class) { 'Server starting...' }

          executable.spawn_server

          wait_until_online.tap do
            RDFPortal.logger.info(self.class) { "Server started at #{options[:port]}" }
          end
        end

        def stop!
          return false unless running_by_pidfile?
          return false unless (pid = Integer(File.read(pid_file).sub('VIRT_PID=', '').strip, exception: false))

          RDFPortal.logger.info(self.class) { 'Server stopping...' }

          Process.kill('INT', pid)
          @connection = nil

          RDFPortal.logger.info(self.class) { 'Server stopped' }

          true
        rescue Errno::ESRCH, Errno::EPERM
          false
        end

        def setup(**options)
          executable.configure_ini_file

          init = false

          unless database_file.exist?
            if (snapshot = options[:snapshot])
              raise Error, "Snapshot not found: #{snapshot}" unless repository.snapshot[snapshot].exist?

              RDFPortal.logger.info(self.class) { "Restoring snapshot #{snapshot}" }
              FileUtils.cp(repository.snapshot[snapshot], database_file)
            else
              executable.create_initial_database
              executable.set_password if @password

              init = true
            end
          end

          start_if_needed!

          return unless init

          connection.enable_cors if options.dig(:database, :options, :cors) == true
          connection.enable_service if options.dig(:database, :options, :federated_query) == true
          connection.disable_text_index if options.dig(:database, :options, :text_index) == false

          connection.checkpoint
        end

        def status
          connection.status
        end

        def setup_loader(**options)
          start_if_needed!

          return unless connection.list_errors.any?

          RDFPortal.logger.info(self.class) { 'Clear previous errors' }
          connection.reset_errors
        end

        def before_load(**options)
          options[:config].each do |config|
            method, dir = if File.dirname(config[:pattern]) == '**'
                            [:ld_dir_all, File.dirname(config[:pattern], 2)]
                          else
                            [:ld_dir, File.dirname(config[:pattern])]
                          end

            unless Dir.exist?(dir)
              RDFPortal.logger.warn(self.class) { "Directory not found: #{dir}" }
              next
            end

            connection.send(method, dir, File.basename(config[:pattern]), config[:graph])
          end
        end

        def exec_load(**options)
          connection.rdf_loader_run(parallel: options[:parallel])

          if (errors = connection.list_errors).any?
            errors.each do |x|
              RDFPortal.logger.error(x[:ll_file]) { x[:ll_error] }
            end

            raise Error, 'Errors occurred during loading, fix problems and try again.'
          end

          connection.checkpoint
        end

        def after_load(**options)
          stop!

          RDFPortal.logger.info(self.class) { 'Copying snapshot...' }

          FileUtils.cp(repository.working.database_dir.join('virtuoso.db'), repository.snapshot[options[:name]])
          FileUtils.cp(repository.working.cache_file, repository.snapshot.cache_file)

          start_if_needed!
        end

        def cleanup_loader(**options); end

        def publish(**options)
          stop!

          return unless options[:dest]

          dest = Repository::Release.new(options[:dest])
          dest.prepare

          RDFPortal.logger.info(self.class) { 'Copying database files' }

          FileUtils.cp(repository.working.database_dir.join('virtuoso.db'), dest.database_dir)
          FileUtils.cp_r(repository.working.log_dir, dest)
          FileUtils.cp(repository.working.cache_file, dest)
        end

        def environment(**options)
          return unless pid_file.exist?

          pid = Integer(File.read(pid_file).sub('VIRT_PID=', '').strip, exception: false)

          conf = executable.current_config(pid)

          case File.basename(conf)
          when 'virtuoso.ini'
            Environment::LOAD
          when 'virtuoso_stat.ini'
            Environment::STAT
          else
            nil
          end
        end

        def statistics(**options)
          statistics = Statistics.new(self)

          gspo = options[:output_dir].join('gspo.yml.gz')
          count = options[:output_dir].join('gspo_count.yml.gz')
          stat = options[:output_dir].join('statistics.yml')
          void = options[:output_dir].join('void_plus.ttl')
          prefixes = Statistics::Vocab.prefixes

          unless gspo.exist?
            RDFPortal.logger.info(self.class) { 'Collecting GSPO...' }
            statistics.gspo(gspo)
          end

          unless count.exist?
            RDFPortal.logger.info(self.class) { 'Counting GSPO...' }
            statistics.gspo_count(gspo, count)
          end

          unless stat.exist?
            RDFPortal.logger.info(self.class) { 'Aggregating statistics...' }
            File.write(stat, YAML.dump(statistics.statistics(count)))
          end

          unless void.exist?
            RDFPortal.logger.info(self.class) { 'Generating VoID...' }
            File.write(void, statistics.void(count).dump(:turtle, prefixes:))
          end
        end

        def connection
          @connection ||= Connection.new(self)
        end

        def executable
          @executable ||= Executable.new(self, environment: options[:environment])
        end

        private

        def database_file
          repository.working.join('db', 'virtuoso.db')
        end

        def pid_file
          repository.working.join('db', 'virtuoso.lck')
        end

        def log_file
          repository.working.join('db', 'virtuoso.log')
        end

        def running_by_socket?(connect_timeout: 1.0)
          Timeout.timeout(connect_timeout) do
            Socket.tcp(options[:host], options[:port], connect_timeout:).close
            true
          end
        rescue StandardError
          false
        end

        def running_by_pidfile?
          return false unless pid_file.exist?

          pid = Integer(File.read(pid_file).sub('VIRT_PID=', '').strip, exception: false)

          return false unless pid

          Process.kill(0, pid)

          true
        rescue Errno::ESRCH
          false
        rescue Errno::EPERM
          true
        end

        def wait_until_online(timeout: 300)
          start_pos = log_file.exist? ? log_file.size : 0

          Timeout.timeout(timeout) do
            sleep 1 until log_file.exist?

            File.open(log_file, 'r') do |f|
              f.seek(start_pos, IO::SEEK_SET)

              loop do
                if (line = f.gets)
                  return true if line.include?('Server online at')
                else
                  sleep 1
                end
              end
            end
          end
        rescue Timeout::Error
          raise Error, 'Virtuoso server did not get online in time'
        end
      end
    end
  end
end
