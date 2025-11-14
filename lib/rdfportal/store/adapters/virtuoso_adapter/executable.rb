# frozen_string_literal: true

require 'sequel'
require 'odbc'

module RDFPortal
  module Store
    module Adapters
      class VirtuosoAdapter
        class Executable
          extend Forwardable
          include ExternalCommand

          def initialize(adapter)
            @adapter = adapter
          end

          def_delegators :@adapter, :name, :repository, :options

          def configure_ini_file
            unless ini_file.exist?
              RDFPortal.logger.info(self.class) { "Copy template to #{ini_file}" }

              FileUtils.cp(find_ini_template, ini_file)
            end

            RDFPortal.logger.info(self.class) { 'Configure ini file' }

            ini_settings.each do |section, settings|
              settings.each do |key, value|
                cmd = [inifile_bin.to_s,
                       '+inifile', ini_file.to_s,
                       '+section', section,
                       '+key', key,
                       '+value', value.to_s]

                run_cmd!(*cmd, command_log: :info, stdout: :info, stderr: :info)
              end
            end
          end

          def create_initial_database
            RDFPortal.logger.info(self.class) { 'Create initial database' }

            cmd = [virtuoso_bin.to_s,
                   '+foreground',
                   '+checkpoint-only',
                   '+configfile', ini_file.to_s]

            run_cmd!(*cmd, command_log: :info, stdout: :info, stderr: :info)
          end

          def set_password
            RDFPortal.logger.info(self.class) { 'Set password' }

            cmd = [virtuoso_bin.to_s,
                   '+foreground',
                   '+checkpoint-only',
                   '+configfile', ini_file.to_s,
                   '+pwdold', 'dba',
                   '+pwddba', options[:password],
                   '+pwddav', options[:password]]

            run_cmd!(*cmd, command_log: :info, stdout: :info, stderr: :info)
          end

          def spawn_server
            cmd = [virtuoso_bin.to_s, '+configfile', ini_file.to_s]

            pid = Process.spawn(*cmd, pgroup: true)

            Process.detach(pid)
          end

          def inifile_bin
            RDFPortal.virtuoso_home.join('bin', 'inifile')
          end

          def virtuoso_bin
            RDFPortal.virtuoso_home.join('bin', 'virtuoso-t')
          end

          def working_dir
            repository.working
          end

          def ini_file
            working_dir.join('db', 'virtuoso.ini')
          end

          private

          def find_ini_template
            if (path = RDFPortal.virtuoso_home.join('installer', 'virtuoso.ini.sample')).exist?
              path.to_s
            elsif ENV['RDFPORTAL_VIRTUOSO_INI'] && FileTest.exist?(ENV['RDFPORTAL_VIRTUOSO_INI'])
              ENV['RDFPORTAL_VIRTUOSO_INI']
            else
              raise Error, 'Failed to find ini template, set `RDFPORTAL_VIRTUOSO_INI` point to virtuoso.ini.sample'
            end
          end

          def ini_settings
            required = {
              Database: {
                DatabaseFile: working_dir.join('db', 'virtuoso.db').to_s,
                ErrorLogFile: working_dir.join('db', 'virtuoso.log').to_s,
                LockFile: working_dir.join('db', 'virtuoso.lck').to_s,
                TransactionFile: working_dir.join('db', 'virtuoso.trx').to_s,
                xa_persistent_file: working_dir.join('db', 'virtuoso.pxa').to_s
              },
              TempDatabase: {
                DatabaseFile: working_dir.join('db', 'virtuoso-temp.db').to_s,
                TransactionFile: working_dir.join('db', 'virtuoso-temp.trx').to_s
              },
              Parameters: {
                DirsAllowed: dirs_allowed.join(', ')
              }
            }

            return required unless (v = options.dig(:database, :settings)) && v.is_a?(Hash)

            v.deep_merge(required)
          end

          def dirs_allowed
            dirs = [RDFPortal.datasets_dir.realpath]

            datasets_directory_prefix.each do |prefix|
              dirs << prefix if dirs.none? { |dir| prefix.to_s.start_with?(dir.to_s) }
            end

            dirs
          end

          def datasets_directory_prefix
            Array(options.dig(:load, :datasets)).map { |x| RDFPortal.dataset_config(x[:name]) }
                                                .filter_map { |x| x.dig(:directory, :prefix) }
                                                .map { |x| Pathname.new(x).realpath }
                                                .sort
          end
        end
      end
    end
  end
end
