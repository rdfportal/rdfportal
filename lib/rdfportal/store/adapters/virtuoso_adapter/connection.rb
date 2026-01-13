# frozen_string_literal: true

require 'sequel'
require 'odbc'

module RDFPortal
  module Store
    module Adapters
      class VirtuosoAdapter
        class Connection
          extend Forwardable

          class LoadList
            class << self
              def all(connection)
                connection.from('DBA.LOAD_LIST')
              end

              def errors(connection)
                connection.from('DBA.LOAD_LIST').exclude(ll_error: nil)
              end
            end

            module State
              NOT_STARTED = 0
              GOING = 1
              DONE = 2
            end

            attr_reader :ll_file, :ll_graph, :ll_state, :ll_started, :ll_done, :ll_host, :ll_work_time, :ll_error

            def initialize(**attributes)
              @ll_file = attributes[:ll_file]
              @ll_graph = attributes[:ll_graph]
              @ll_state = attributes[:ll_state]
              @ll_started = attributes[:ll_started]
              @ll_done = attributes[:ll_done]
              @ll_host = attributes[:ll_host]
              @ll_work_time = attributes[:ll_work_time]
              @ll_error = attributes[:ll_error]
            end
          end

          class << self
            DRIVER_FILENAME = 'virtodbc_r.so'

            def find_driver
              if (lib = RDFPortal.virtuoso_home.join('lib', DRIVER_FILENAME)).exist?
                lib.to_s
              elsif ENV['RDFPORTAL_VIRTUOSO_LIB']
                if (lib = Pathname.new(ENV['RDFPORTAL_VIRTUOSO_LIB']).join(DRIVER_FILENAME)).exist?
                  lib.to_s
                else
                  raise Error, "File not found: #{lib}"
                end
              else
                raise Error, "Failed to find driver: #{DRIVER_FILENAME}"
              end
            end
          end

          def initialize(adapter)
            @adapter = adapter
          end

          def_delegators :@adapter, :name, :repository, :options
          def_delegators :connection, :run, :fetch

          def shutdown
            connection.run('SHUTDOWN')
          rescue Sequel::DatabaseConnectionError, ODBC::Error
            @connection = nil
          end

          def status
            connection.fetch('status()').map { |x| x[:report] }.join("\n")
          end

          def checkpoint
            RDFPortal.logger.info(self.class) { 'Start checkpoint' }

            connection.run 'CHECKPOINT'

            RDFPortal.logger.info(self.class) { 'Finish checkpoint' }
          end

          def ld_dir(dir, file, graph)
            connection.run "ld_dir ('#{dir}', '#{file}', '#{graph}')"
          end

          def ld_dir_all(dir, file, graph)
            connection.run "ld_dir_all ('#{dir}', '#{file}', '#{graph}')"
          end

          def rdf_loader_run(parallel: 1)
            raise ArgumentError, '`parallel` must be positive integer' unless parallel.positive?

            RDFPortal.logger.info(self.class) { "Start rdf_loader_run (parallel = #{parallel})" }

            time = Benchmark.realtime do
              threads = (1..parallel).map do
                Thread.new { connection.run('rdf_loader_run(log_enable => 2)') }
              end
              threads.each(&:join)
            end

            RDFPortal.logger.info(self.class) { "Finish rdf_loader_run in #{time.to_i.readable_duration}" }
          end

          def rdf_load_stop
            connection.run 'rdf_load_stop()'
          end

          def load_list
            LoadList.all(connection).all { |x| LoadList.new(**x) }
          end

          def list_errors
            LoadList.errors(connection).all { |x| LoadList.new(**x) }
          end

          def reset_errors
            LoadList.errors(connection).delete
          end

          def enable_cors
            RDFPortal.logger.info(self.class) { 'Enable CORS' }

            connection.run "DB.DBA.VHOST_REMOVE (lpath=>'/sparql')"
            connection.run "DB.DBA.VHOST_DEFINE (lpath=>'/sparql',ppath=>'/!sparql/',is_dav=>1,vsp_user=>'dba'," \
                           "opts=>vector('cors', '*', 'browse_sheet', '', 'noinherit', 'yes'))"
          end

          def enable_service
            RDFPortal.logger.info(self.class) { 'Enable federated function' }

            connection.run 'GRANT SELECT ON DB.DBA.SPARQL_SINV_2 TO "SPARQL"'
            connection.run 'GRANT EXECUTE ON DB.DBA.SPARQL_SINV_IMP TO "SPARQL"'
            connection.run 'GRANT SPARQL_LOAD_SERVICE_DATA TO "SPARQL"'
            connection.run 'GRANT EXECUTE ON DB.DBA.SPARQL_SD_PROBE TO "SPARQL"'
            connection.run 'GRANT SPARQL_SPONGE TO "SPARQL"'
            connection.run 'GRANT EXECUTE ON DB.DBA.L_O_LOOK TO "SPARQL"'
            connection.run "DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('nobody', 7)"
          end

          def disable_text_index(graph = nil, predicate = nil, reason = nil)
            params = index_params(graph, predicate, reason)

            RDFPortal.logger.info(self.class) { 'Disable text index' }

            connection.run "DB.DBA.RDF_OBJ_FT_RULE_DEL (#{params[0]}, #{params[1]}, #{params[2]})"
          end

          def enable_text_index(graph = nil, predicate = nil, reason = nil)
            params = index_params(graph, predicate, reason)

            RDFPortal.logger.info(self.class) { 'Enable text index' }

            connection.run "DB.DBA.RDF_OBJ_FT_RULE_ADD (#{params[0]}, #{params[1]}, #{params[2]})"
            connection.run 'DB.DBA.VT_INC_INDEX_DB_DBA_RDF_OBJ ()'
          end

          def index_params(graph = nil, predicate = nil, reason = nil)
            [graph ? "'#{graph}'" : 'null', predicate ? "'#{predicate}'" : 'null', reason ? "'#{reason}'" : "'All'"]
          end

          def graphs
            sparql = <<~SPARQL
              SELECT DISTINCT ?graph {
                GRAPH ?graph {
                  ?s ?p ?o .
                }
              }
            SPARQL

            connection.fetch("SPARQL #{sparql.gsub(/\n\s*/, ' ').strip}").map { |x| x[:graph] }
          end

          def odbc_config
            {
              adapter: 'odbc',
              drvconnect: conn_string,
              loggers: [RDFPortal.logger],
              max_connections: 50,
              pool_timeout: 10
            }
          end

          def conn_string
            {
              'Driver' => self.class.find_driver,
              'Host' => "#{options[:host]}:#{options[:port]}",
              'UID' => options[:user],
              'PWD' => options[:password]
            }.map { |k, v| "#{k}=#{v}" }.join(';')
          end

          private

          # @return [Sequel::ODBC::Database]
          def connection
            @connection ||= Sequel.connect(odbc_config)
          end
        end
      end
    end
  end
end
