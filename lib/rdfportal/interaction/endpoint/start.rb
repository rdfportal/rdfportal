# frozen_string_literal: true

module RDFPortal
  module Interaction
    module Endpoint
      require_relative 'base'

      class Start < Base
        def execute
          server.start_if_needed!
        end
      end
    end
  end
end
