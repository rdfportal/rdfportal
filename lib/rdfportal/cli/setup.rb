# frozen_string_literal: true

module RDFPortal
  module CLI
    module Setup
      require 'rdfportal/cli/setup/faktory'

      class Commands < Thor
        class << self
          def exit_on_failure?
            true
          end
        end

        register Faktory, 'faktory', 'faktory', Faktory.desc
      end
    end
  end
end
