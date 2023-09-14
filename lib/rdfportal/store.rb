# frozen_string_literal: true

module RDFPortal
  module Store
    PROGRAM_NAME = 'rdfportal-store'

    require 'rdfportal/store/base'
    require 'rdfportal/store/connection_adapters'
    require 'rdfportal/store/port'
    require 'rdfportal/store/util'
  end
end
