# frozen_string_literal: true

require 'rdfportal/loader/interaction'

module RDFPortal
  module Loader
    module Interaction
      class Status < DatabaseInteraction
        boolean :verbose, default: false

        def execute
          return unless (connection = compose(Connect, **inputs.to_h))

          puts connection.status(verbose:)
        end
      end
    end
  end
end
