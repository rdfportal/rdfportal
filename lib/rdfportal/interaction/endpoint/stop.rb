# frozen_string_literal: true

module RDFPortal
  module Interaction
    module Endpoint
      require_relative 'base'

      class Stop < Base
        def execute
          server.stop!
        end
      end
    end
  end
end
