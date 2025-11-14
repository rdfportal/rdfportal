# frozen_string_literal: true

require 'timeout'

module RDFPortal
  module Job
    class ServerManager
      LOCK_FILE = RDFPortal.home.join('faktory', 'server.lock')
      PID_FILE = RDFPortal.home.join('pids', 'faktory-server.pid')
      LOG_FILE = RDFPortal.home.join('log', 'faktory-server.log')
      READY_TIMEOUT = 30

      class << self
        def server_running?(connect_timeout: 1.0)
          Timeout.timeout(connect_timeout) do
            Socket.tcp(RDFPortal.faktory_host, RDFPortal.faktory_network_port, connect_timeout:).close
            true
          end
        rescue StandardError
          false
        end

        def server_running_by_pidfile?
          if RDFPortal.faktory == :docker
            return DockerHelper.container_status(DOCKER_CONTAINER, printer: :null) == :running
          end

          return false unless PID_FILE.exist?

          pid = Integer(File.read(PID_FILE), exception: false)

          return false unless pid

          Process.kill(0, pid)

          true
        rescue Errno::ESRCH
          false
        rescue Errno::EPERM
          true
        end

        def start_if_needed!
          return true if server_running?

          unless File.exist?(LOCK_FILE)
            FileUtils.mkdir_p(LOCK_FILE.dirname)
            FileUtils.touch(LOCK_FILE)
          end

          File.open(LOCK_FILE, File::RDWR) do |f|
            lock = f.flock(File::LOCK_EX | File::LOCK_NB)

            return wait_until_ready unless lock

            begin
              return true if server_running?

              spawn_server!
              wait_until_ready
            ensure
              f.flock(File::LOCK_UN)
              begin
                LOCK_FILE.unlink
              rescue StandardError
                nil
              end
            end
          end
        end

        def stop!
          if RDFPortal.faktory == :docker
            DockerHelper.stop_container(DOCKER_CONTAINER, printer: :null)

            return true
          end

          return false unless PID_FILE.exist?

          pid = Integer(File.read(PID_FILE), exception: false)

          return false unless pid

          Process.kill('TERM', pid)

          PID_FILE.unlink

          true
        rescue StandardError
          false
        end

        private

        def wait_until_ready
          t = Time.now + READY_TIMEOUT

          until Time.now - t > READY_TIMEOUT
            return true if server_running?

            sleep 1
          end

          raise Error, 'Faktory server did not get ready in time'
        end

        def faktory_env
          {
            'FAKTORY_PASSWORD' => RDFPortal.faktory_password
          }.compact_blank
        end

        def spawn_server!
          if RDFPortal.faktory == :docker
            DockerHelper.run_container(DOCKER_IMAGE,
                                       detach: true,
                                       remove: true,
                                       env: faktory_env,
                                       volume: {
                                         RDFPortal.home.join('faktory').to_s => '/var/lib/faktory'
                                       },
                                       publish: {
                                         RDFPortal.faktory_network_port => 7419,
                                         RDFPortal.faktory_webui_port => 7420
                                       },
                                       name: DOCKER_CONTAINER,
                                       printer: :null)
          else
            # Faktory 1.9.3
            # Copyright © 2025 Contributed Systems LLC
            # Licensed under the GNU Affero Public License 3.0
            # -b [binding]	Network binding (use :7419 to listen on all interfaces), default: localhost:7419
            # -w [binding]	Web UI binding (use :7420 to listen on all interfaces), default: localhost:7420
            # -e [env]	Set environment (development, staging, production), default: development
            # -l [level]	Set logging level (error, warn, info, debug), default: info
            # -v		Show version and license information
            # -h		This help screen
            cmd = []
            cmd << Job.faktory_bin
            cmd << '-b'
            cmd << "0.0.0.0:#{RDFPortal.faktory_network_port}"
            cmd << '-w'
            cmd << "0.0.0.0:#{RDFPortal.faktory_webui_port}"
            cmd << '-d'
            cmd << RDFPortal.home.join('faktory', 'db').to_s

            LOG_FILE.dirname.mkpath
            PID_FILE.dirname.mkpath

            pid = Process.spawn(faktory_env, *cmd, out: LOG_FILE.to_s, err: LOG_FILE.to_s, pgroup: true)
            Process.detach(pid)
            begin
              File.write(PID_FILE, pid)
            rescue StandardError
              nil
            end
          end
        end
      end
    end
  end
end
