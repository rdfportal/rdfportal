# frozen_string_literal: true

module RDFPortal
  module Interaction
    module Endpoint
      require_relative 'base'

      class Stop < Base
        hash :options do
          boolean :force, default: false
        end

        def execute
          server.stop!(**options)
        end
      end
    end
  end
end
