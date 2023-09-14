# frozen_string_literal: true

require 'rdfportal/loader/interaction'

module RDFPortal
  module Loader
    module Interaction
      class Setup < DatabaseInteraction
        def execute
          # make symbolic link in releases directory
          unless (releases = repository.endpoints[name].releases).exist?
            releases.mkpath
          end

          work_dir.directories.each(&:mkpath)

          RDFPortal.logger = Store::Base.logger = Logger.new(work_dir.log / 'loader.log')

          establish_connection.setup(**environment[:options])
        end
      end
    end
  end
end
