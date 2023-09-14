# frozen_string_literal: true

require 'benchmark'

module RDFPortal
  module Store
    module ConnectionAdapters
      class Virtuoso
        class ConnectionBad < Error; end

        class Connection
          include Util::ExternalCommand

          DEFAULT_HOST = 'localhost'
          DEFAULT_PORT = 1111
          DEFAULT_USER = 'dba'
          DEFAULT_PASSWORD = 'dba'

          def initialize(**config)
            @host = config[:host] || DEFAULT_HOST
            @port = config[:port] || DEFAULT_PORT
            @user = config[:user] || DEFAULT_USER
            @password = config[:password] || DEFAULT_PASSWORD
            @bin = config[:bin]

            return if Port.listen?(@port)

            raise ConnectionBad, "connection to server at \"#{@host}\", port #{@port} failed: Connection refused"
          end

          def shutdown
            exec_query 'shutdown;'
          end

          def status
            exec_query 'status();'
          end

          def password(new_password)
            exec_query("set password #{@password} #{new_password};", log: false).tap { @password = new_password }
          end

          def enable_cors
            Base.logger.info(PROGRAM_NAME) { 'enable CORS' }

            query = <<~QUERY
              DB.DBA.VHOST_REMOVE (lpath=>'/sparql');
              DB.DBA.VHOST_DEFINE (lpath=>'/sparql', ppath=>'/!sparql/', is_dav=>1, vsp_user=>'dba', opts=>vector('cors', '*', 'browse_sheet', '', 'noinherit', 'yes'));
            QUERY

            exec_query query
          end

          def enable_service
            Base.logger.info(PROGRAM_NAME) { 'enable federated function' }

            query = <<~QUERY
              GRANT SELECT ON DB.DBA.SPARQL_SINV_2 TO "SPARQL";
              GRANT EXECUTE ON DB.DBA.SPARQL_SINV_IMP TO "SPARQL";
              GRANT SPARQL_LOAD_SERVICE_DATA TO "SPARQL";
              GRANT EXECUTE ON DB.DBA.SPARQL_SD_PROBE TO "SPARQL";
              GRANT SPARQL_SPONGE TO "SPARQL";
              GRANT EXECUTE ON DB.DBA.L_O_LOOK TO "SPARQL";
              DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('nobody', 7);
            QUERY

            exec_query query
          end

          def disable_text_index(graph = nil, predicate = nil, reason = nil)
            params = index_params(graph, predicate, reason)

            Base.logger.info(PROGRAM_NAME) { "disable text index (parameters: #{params})" }

            exec_query "DB.DBA.RDF_OBJ_FT_RULE_DEL (#{params[0]}, #{params[1]}, #{params[2]});"
          end

          def enable_text_index(graph = nil, predicate = nil, reason = nil)
            params = index_params(graph, predicate, reason)

            Base.logger.info(PROGRAM_NAME) { "enable text index [#{params}]" }

            query = <<~QUERY
              DB.DBA.RDF_OBJ_FT_RULE_ADD (#{params[0]}, #{params[1]}, #{params[2]});
              DB.DBA.VT_INC_INDEX_DB_DBA_RDF_OBJ ();
            QUERY

            exec_query query
          end

          def ld_dir(dir, file, graph)
            exec_query "ld_dir ('#{dir}', '#{file}', '#{graph}');"
          end

          def ld_dir_all(dir, file, graph)
            exec_query "ld_dir_all ('#{dir}', '#{file}', '#{graph}');"
          end

          def rdf_loader_run(parallel: 1, checkpoint: true)
            raise ArgumentError, '`parallel` must be positive integer' unless parallel.positive?

            Base.logger.info(PROGRAM_NAME) { "start loading (parallel = #{parallel})" }

            time = Benchmark.realtime do
              threads = []
              (1..parallel).each do
                threads << Thread.new { exec_query('rdf_loader_run (log_enable=>2);') }
              end
              threads.each(&:join)
            end

            Base.logger.info(PROGRAM_NAME) { "loading took #{time.to_i.readable_duration}" }

            return unless checkpoint

            self.checkpoint
          end

          def checkpoint
            Base.logger.info(PROGRAM_NAME) { 'start checkpoint' }

            time = Benchmark.realtime do
              exec_query 'checkpoint;'
            end

            Base.logger.info(PROGRAM_NAME) { "checkpoint took #{time.to_i.readable_duration}" }
          end

          def rdf_load_stop
            exec_query 'rdf_load_stop();'
          end

          module LoadStatus
            TO_BE_LOADED = 0
            IN_PROGRESS = 1
            COMPLETE = 2
          end

          def graph
            exec_query 'SPARQL SELECT DISTINCT ?g WHERE { GRAPH ?g { ?s ?p ?o . } };'
          end

          def count
            exec_query 'SPARQL SELECT ?g (COUNT(*) AS ?triples) WHERE { GRAPH ?g { ?s ?p ?o } } GROUP BY ?g;'
          end

          def list
            fields = ['ll_file AS file',
                      'll_graph AS graph',
                      "(CASE ll_state WHEN 0 THEN 'added' " \
                      "WHEN 1 THEN 'in progress' " \
                      "WHEN 2 THEN 'complete' " \
                      "ELSE 'unknown' END) AS state",
                      "CONCAT(CAST((ll_done - ll_started) / 3600 AS INT), 'h ', " \
                      "MOD((ll_done - ll_started) / 60, 60), 'm ', " \
                      "MOD(ll_done - ll_started, 60), 's') AS took"]

            select_load_list fields.join(', ')
          end

          def list_error
            select_load_list 'll_file, ll_graph', 'll_error IS NOT NULL'
          end

          def count_to_be_loaded
            count_load_status LoadStatus::TO_BE_LOADED
          end

          def count_in_progress
            count_load_status LoadStatus::IN_PROGRESS
          end

          def count_complete
            count_load_status LoadStatus::COMPLETE
          end

          def count_all
            count_load_list nil, nil
          end

          def count_error
            count_load_list nil, 'll_error IS NOT NULL'
          end

          def reset_error
            exec_query 'DELETE FROM dba.load_list WHERE ll_error IS NOT NULL;'
          end

          # @return [[Process::Status, String]]
          def exec_query(query, **options)
            Base.logger.debug(PROGRAM_NAME) { "isql: #{query}" } unless options[:log] == false

            cmd = [@bin,
                   '-H', @host.to_s,
                   '-S', @port.to_s,
                   '-U', @user.to_s,
                   '-P', @password.to_s,
                   'verbose=off',
                   "exec=\"#{query.gsub(/\R/, ' ')}\""]

            ret = []

            status = external_command(*cmd, **options.merge(log: false)) do |out|
              ret << out
              Base.logger.debug(PROGRAM_NAME) { out } unless options[:log] == false
            end

            [status, ret.join("\n")]
          end

          private

          def index_params(graph = nil, predicate = nil, reason = nil)
            [graph ? "'#{graph}'" : 'null', predicate ? "'#{predicate}'" : 'null', reason ? "'#{reason}'" : "'All'"]
          end

          def select_load_list(field = nil, where = nil)
            _status, ret = exec_query "SELECT #{field || '*'} FROM dba.load_list#{" WHERE #{where}" if where};"

            ret
          end

          def count_load_list(field = nil, where = nil)
            _status, ret = exec_query "SELECT COUNT(#{field || '*'}) FROM dba.load_list#{" WHERE #{where}" if where};"

            Integer(ret.split("\n").last, exception: false)
          end

          def count_load_status(status)
            count_load_list nil, "ll_state = #{status}"
          end
        end
      end
    end
  end
end
