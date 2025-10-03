# frozen_string_literal: true

module RDFPortal
  module CLI
    class Job < Thor
      class << self
        def exit_on_failure?
          true
        end
      end

      desc 'status', 'Show status'

      def status
        info = begin
                 RDFPortal::Job::ServerManager.start_if_needed!

                 Faktory.server(&:info)
               rescue Errno::ECONNREFUSED
                 abort 'Server not running'
               end

        say JSON.pretty_generate(info)
      end

      desc 'fetch <NAME>', 'Submit a job to fetch dataset'

      def fetch(name)
        require 'rdfportal/job/worker/fetch_worker'

        RDFPortal::Job::ServerManager.start_if_needed!
        RDFPortal::Job::WorkerManager.worker_for(:fetch).start_if_needed!

        Worker::FetchWorker.perform_async(name)
      end

      desc 'load', 'Submit a job to load dataset'

      def load(name)
        require 'rdfportal/job/worker/load_worker'

        RDFPortal::Job::ServerManager.start_if_needed!
        RDFPortal::Job::WorkerManager.worker_for(:load).start_if_needed!

        Worker::LoadWorker.perform_async(name)
      end
    end
  end
end
