# frozen_string_literal: true

module RDFPortal
  module Job
    class WorkerManager
      WORKERS = %i[fetch load stat].freeze
      IDLE_EXIT_SECONDS = 10

      class << self
        def worker_for(name)
          raise Error, "Invalid worker name: #{name}" unless WORKERS.include?(name.to_sym)

          new(name, name, "#{name}_worker")
        end
      end

      attr_reader :name, :queue, :worker_source

      def initialize(name, queue, worker_source)
        @name = name
        @queue = queue
        @worker_source = worker_source
      end

      def running?
        return false unless File.exist?(pid_file)

        pid = Integer(File.read(pid_file), exception: false)

        return false unless pid

        Process.kill(0, pid)

        true
      rescue Errno::ESRCH
        false
      rescue Errno::EPERM
        true
      end

      def start_if_needed!
        return if running?

        unless File.exist?(lock_file)
          FileUtils.mkdir_p(lock_file.dirname)
          FileUtils.touch(lock_file)
        end

        File.open(lock_file, File::RDWR) do |f|
          lock = f.flock(File::LOCK_EX | File::LOCK_NB)

          break unless lock

          begin
            spawn_worker! unless running?
          ensure
            f.flock(File::LOCK_UN)
            begin
              lock_file.unlink
            rescue StandardError
              nil
            end
          end
        end
      end

      private

      def lock_file
        @lock_file ||= RDFPortal.home.join('faktory', "#{name}_worker.lock")
      end

      def pid_file
        @pid_file ||= RDFPortal.home.join('pids', "#{name}_worker.pid")
      end

      def log_file
        @log_file ||= RDFPortal.home.join('log', 'faktory', "#{name}_worker.log")
      end

      def spawn_worker!
        env = {
          'IDLE_EXIT_SECONDS' => IDLE_EXIT_SECONDS.to_s
        }

        cmd = []
        cmd << File.expand_path('../../../bin/worker_daemon', __dir__)
        cmd << '--concurrency'
        cmd << RDFPortal.send("worker_#{queue}_concurrency").to_s
        cmd << '--log-file'
        cmd << log_file.to_s
        cmd << '--queue'
        cmd << queue.to_s
        cmd << '--host'
        cmd << RDFPortal.faktory_host
        cmd << '--port'
        cmd << RDFPortal.faktory_network_port.to_s
        if RDFPortal.faktory_password.present?
          cmd << '--password'
          cmd << RDFPortal.faktory_password
        end
        cmd << File.expand_path("../worker/#{worker_source}.rb", __dir__)

        log_file.dirname.mkpath
        pid_file.dirname.mkpath

        pid = Process.spawn(env, *cmd, pgroup: true)
        Process.detach(pid)
        File.write(pid_file, pid)
      end
    end
  end
end
