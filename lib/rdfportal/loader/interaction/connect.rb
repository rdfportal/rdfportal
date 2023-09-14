# frozen_string_literal: true

require 'rdfportal/loader/interaction'

module RDFPortal
  module Loader
    module Interaction
      class Connect < DatabaseInteraction
        def execute
          unless work_dir.exist?
            warn 'working directory not exist'
            return
          end

          establish_connection
        end
      end
    end
  end
end
