# frozen_string_literal: true

module RDFPortal
  module Interaction
    module Endpoint
      require_relative 'base'

      hash :options do
        boolean :force, default: false
      end

      class Stop < Base
        def execute
          server.stop!(**options)
        end
      end
    end
  end
end
