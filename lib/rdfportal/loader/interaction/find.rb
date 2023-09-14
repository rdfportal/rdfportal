# frozen_string_literal: true

require 'rdfportal/loader/interaction'

module RDFPortal
  module Loader
    module Interaction
      class Find < BaseInteraction
        def execute
          return unless (work_dir = repository.endpoints.working(name)).exist?

          work_dir
        end
      end
    end
  end
end
