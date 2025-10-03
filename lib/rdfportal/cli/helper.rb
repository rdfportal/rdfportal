# frozen_string_literal: true

module RDFPortal
  module CLI
    module Helper
      # @return [String, nil]
      def capture_output(command, **options)
        options[:verbose] ||= false

        run(command, **options, capture: true, abort_on_failure: false)
      rescue StandardError
        nil
      end

      # @return [TrueClass, FalseClass]
      def check_status(command, **options)
        options[:verbose] ||= false

        run(command, **options, abort_on_failure: false)
      rescue StandardError
        false
      end
    end
  end
end
