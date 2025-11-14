# frozen_string_literal: true

require 'rdfportal'

module RDFPortal
  module Worker
    class FetchWorker
      include Faktory::Job

      faktory_options retry: 0, queue: :fetch

      attr_accessor :started_at, :finished_at

      def perform(name, **options)
        log_dir = RDFPortal.home.join('log', 'fetch')
        log_dir.mkpath
        log_dir.glob("*_#{name}.log").sort.reverse.drop(4).each(&:unlink)
        log_file = log_dir.join("#{Time.now.strftime('%Y%m%d')}_#{name}.log")

        RDFPortal.logger = RDFPortal::Logger.new(log_file, broadcast: false)

        self.started_at = Time.now

        action = Interaction::Dataset::Fetch.run(**RDFPortal.dataset_config(name), name:, **options.symbolize_keys)

        raise Error, "Invalid interaction\n#{action.errors.input_error_messages}" unless action.valid?

        self.finished_at = Time.now

        remaining_job_count = (self.remaining_job_count - 1 if respond_to?(:remaining_job_count))

        RDFPortal.logger.info(self.class) { "Result for #{name}\n" + action.result.to_s }

        Notifier::FetchNotifier.new(action.result,
                                    started_at:,
                                    finished_at:,
                                    remaining_job_count:,
                                    log_file:).deliver
      rescue StandardError => e
        RDFPortal.logger.error(self.class) { e.full_message }
        Notifier::ExceptionNotifier.new(e, title: "Update failed: #{name}", log_file:).deliver
        raise e
      ensure
        RDFPortal.reset_logger!
      end
    end
  end
end
