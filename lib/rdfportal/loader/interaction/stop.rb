# frozen_string_literal: true

require 'rdfportal/loader/interaction'

module RDFPortal
  module Loader
    module Interaction
      class Stop < DatabaseInteraction
        def execute
          RDFPortal.logger = Store::Base.logger = Logger.new($stdout)

          unless work_dir.exist?
            RDFPortal.logger.warn(PROGRAM_NAME) { 'working directory not exist' }
            return
          end

          Store::Base.stop(**environment)
        end
      end
    end
  end
end
