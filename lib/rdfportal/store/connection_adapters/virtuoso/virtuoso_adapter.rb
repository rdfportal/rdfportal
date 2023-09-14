# frozen_string_literal: true

require 'rdfportal/store/connection_adapters/virtuoso/connection'
require 'rdfportal/store/connection_adapters/virtuoso/virtuoso'

module RDFPortal
  module Store
    module ConnectionAdapters
      class VirtuosoAdapter < AbstractAdapter
        ADAPTER_NAME = 'Virtuoso'

        class << self
          def environment(database_dir, datasets_dir, **config)
            datasets_dir.mkpath unless datasets_dir.exist?

            {
              ini: database_dir / 'virtuoso.ini',
              environment: {
                Database: {
                  DatabaseFile: database_dir / 'virtuoso.db',
                  ErrorLogFile: database_dir / 'virtuoso.log',
                  LockFile: database_dir / 'virtuoso.lck',
                  TransactionFile: database_dir / 'virtuoso.trx',
                  xa_persistent_file: database_dir / 'virtuoso.pxa'
                },
                TempDatabase: {
                  DatabaseFile: database_dir / 'virtuoso-temp.db',
                  TransactionFile: database_dir / 'virtuoso-temp.trx'
                },
                Parameters: {
                  DirsAllowed: [config.dig(:Parameters, :DirsAllowed), datasets_dir.realpath].compact.join(', ')
                }
              }
            }
          end

          def new_client(**config)
            db = Virtuoso.new(**config)

            unless db.running?
              db.init
              db.start
            end

            db.connect(host: config[:host],
                       port: db.isql_port,
                       user: config[:user],
                       password: config[:password])
          end

          def start(**config)
            db = Virtuoso.new(**config)
            db.start unless db.running?
          end

          def stop(**config)
            db = Virtuoso.new(**config)
            db.stop if db.running?
          end

          def snapshot(destination, **config)
            db = Virtuoso.new(**config)
            db.snapshot(destination)
          end

          def restore(source, **config)
            db = Virtuoso.new(**config)
            db.restore(source)
          end

          def publish(source, destination, **config)
            db = Virtuoso.new(**config)
            if db.running?
              Base.logger.info(PROGRAM_NAME) { 'stopping server before publishing' }
              db.stop
            end

            FileUtils.mv source, destination
            Base.logger.info(PROGRAM_NAME) { "moved #{source} to #{destination}" }

            ((dest = Pathname.new(destination)).glob('db/virtuoso*') - [dest / 'db/virtuoso.db']).each do |f|
              f.unlink
              Base.logger.info(PROGRAM_NAME) { "removed #{f}" }
            end
          end
        end

        def setup(**options)
          @connection.enable_cors if options[:cors]
          @connection.enable_service if options[:federated_query]
          @connection.disable_text_index if options[:text_index] == false
        end

        def start(**config)
          self.class.start(**@config.merge(config))
        end

        def stop(**config)
          self.class.stop(**@config.merge(config))
        end

        def snapshot(destination, **config)
          self.class.snapshot(destination, **@config.merge(config))
        end

        def restore(source, **config)
          self.class.restore(source, **@config.merge(config))
        end

        def add_file(file, graph, **_options)
          @connection.ld_dir(File.dirname(file), File.basename(file), graph)
        end

        def status(**options)
          ret = []
          error = @connection.count_error

          if options[:verbose]
            ret << "[Load List: #{all = @connection.count_all}]"
            ret << @connection.list if all.positive?
            ret << "\n"
            ret << "[Errors: #{error}]"
            ret << @connection.list_error if error.positive?
            ret << "\n"
          end
          ret << "To be loaded: #{@connection.count_to_be_loaded}"
          ret << " In progress: #{@connection.count_in_progress}"
          ret << "    Complete: #{@connection.count_complete}"
          ret << "       Error: #{error}" unless options[:verbose]

          ret.join("\n")
        end

        def exec_load(**options)
          @connection.rdf_loader_run(parallel: options[:parallel], checkpoint: options[:checkpoint])
        end

        def after_load(**_options)
          @connection.checkpoint
          Base.logger.info(PROGRAM_NAME) { "\n#{@connection.list}" }
          errors = @connection.count_error
          Base.logger.info(PROGRAM_NAME) { "errors: #{errors}" }
          Base.logger.info(PROGRAM_NAME) { "\n#{@connection.list_error}" } if errors&.positive?
        end

        def exec_query(query, **options)
          @connection.exec_query(query, **options)
        end
      end
    end
  end
end
