# frozen_string_literal: true

require 'thor'

module RDFPortal
  module CLI
    require 'rdfportal/cli/convert'
    require 'rdfportal/cli/dataset'
    require 'rdfportal/cli/doctor'
    require 'rdfportal/cli/endpoint'
    require 'rdfportal/cli/job'
    require 'rdfportal/cli/setup'

    class Main < Thor
      class << self
        def exit_on_failure?
          true
        end
      end

      register Doctor, 'doctor', 'doctor', Doctor.desc

      desc 'setup [SUBCOMMAND]', 'Commands for setup', hide: true
      subcommand :setup, Setup::Commands

      desc 'convert [SUBCOMMAND]', 'Commands for converter'
      subcommand :convert, Convert

      desc 'dataset [SUBCOMMAND]', 'Commands for datasets'
      subcommand :dataset, Dataset

      desc 'endpoint [SUBCOMMAND]', 'Commands for endpoints'
      subcommand :endpoint, Endpoint

      desc 'job [SUBCOMMAND]', 'Commands for job runner'
      subcommand :job, Job

      desc 'version', 'Show version number'

      def version
        puts "#{File.basename($PROGRAM_NAME)} #{VERSION}"
      end

      map %w[--version -v] => :version
    end
  end
end
