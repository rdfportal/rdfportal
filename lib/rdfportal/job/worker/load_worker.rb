# frozen_string_literal: true

require 'rdfportal'

module RDFPortal
  module Worker
    class LoadWorker
      include Faktory::Job

      faktory_options retry: 0, queue: :load

      attr_accessor :started_at, :finished_at

      def perform(name, **_options)
        log_dir = RDFPortal.home.join('log', 'load')
        log_dir.mkpath
        log_dir.glob("*_#{name}.log").sort.reverse.drop(4).each(&:unlink)
        log_file = log_dir.join("#{Time.now.strftime('%Y%m%d')}_#{name}.log")

        RDFPortal.logger = RDFPortal::Logger.new(log_file, broadcast: false)

        sleep 10

        RDFPortal.logger.info(self.class) { "remaining_job_count: #{remaining_job_count}" }
      end
    end
  end
end
