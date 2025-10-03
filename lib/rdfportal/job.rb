# frozen_string_literal: true

module RDFPortal
  module Job
    DOCKER_IMAGE = 'contribsys/faktory'
    DOCKER_CONTAINER = 'rdfportal-faktory'

    def self.initialize_env
      ENV['FAKTORY_PROVIDER'] ||= 'RDFPORTAL_FAKTORY_PROVIDER'
      ENV['RDFPORTAL_FAKTORY_PROVIDER'] ||= begin
                                              host = RDFPortal.faktory_host
                                              port = RDFPortal.faktory_network_port
                                              password = RDFPortal.faktory_password

                                              if password.present?
                                                "tcp://:#{password}@#{host}:#{port}"
                                              else
                                                "tcp://#{host}:#{port}"
                                              end
                                            end
    end

    def self.faktory_bin
      RDFPortal.home.join('opt', 'faktory', 'bin', 'faktory').to_s
    end

    initialize_env

    require 'rdfportal/job/server_manager'
    require 'rdfportal/job/worker_manager'
  end
end
