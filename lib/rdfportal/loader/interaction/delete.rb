# frozen_string_literal: true

require 'rdfportal/loader/interaction'

module RDFPortal
  module Loader
    module Interaction
      class Delete < DatabaseInteraction
        def execute
          compose(Stop, **inputs.to_h)

          RDFPortal.logger = Store::Base.logger = Logger.new($stdout)

          work_dir.rmtree

          RDFPortal.logger.info(PROGRAM_NAME) { "remove #{work_dir}" }
        end
      end
    end
  end
end
