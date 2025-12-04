# frozen_string_literal: true

module RDFPortal
  module Interaction
    module Endpoint
      require_relative 'base'

      class Statistics < Base
        hash :stat, default: {} do
          boolean :graph, default: true
          string :endpoint, default: nil
        end

        def initialize(inputs = {})
          super
          @environment = Store::Environment::STAT
        end

        def execute
          if server.environment != Store::Environment::STAT
            RDFPortal.logger.info(self.class) { 'Restart server for statistics' }
            server.stop!
            server.setup
          end

          server.statistics(output_dir: repository.working.stat_dir)
        end
      end
    end
  end
end
