# frozen_string_literal: true

module RDFPortal
  module Interaction
    module Endpoint
      require_relative 'base'

      class Statistics < Base
        def initialize(inputs = {})
          @environment = Store::Environment::STAT
          super
        end

        def execute
          if server.environment != Store::Environment::STAT
            RDFPortal.logger.info(self.class) { 'Restart server for statistics' }
            server.stop!
            server.setup
          end

          server.statistics(output_dir: repository.working.stat_dir, void_format: stat[:void_format])

          server.stop!
        end
      end
    end
  end
end
