# frozen_string_literal: true

require 'rdf'
require 'rdf/vocab'
require 'rdf/turtle'

module RDFPortal
  module Store
    module Adapters
      class VirtuosoAdapter
        class Statistics
          extend Forwardable

          require 'rdfportal/store/adapters/virtuoso_adapter/sparql'

          def initialize(adapter)
            @adapter = adapter
          end

          def_delegators :@adapter, :name, :repository, :options

          def statistics(gspo_count_input)
            statistics = Hash.new do |hash, key|
              hash[key] = {
                total_count: 0,
                uniq_subject_count: 0,
                uniq_object_count: 0,
                classes: Set.new,
                properties: Set.new
              }
            end

            aggregate(gspo_count_input).each do |graph, stat|
              dataset = if graph_disabled?
                          name
                        else
                          datasets.find { |x| x[:graph] == graph }&.fetch(:name) || graph
                        end

              statistics[dataset][:total_count] += stat[:total_entity_count].to_i
              statistics[dataset][:uniq_subject_count] += stat[:distinct_subject_count].to_i
              statistics[dataset][:uniq_object_count] += stat[:distinct_object_count].to_i
              statistics[dataset][:classes].merge(stat.fetch(:classes, []))
              statistics[dataset][:properties].merge(stat.fetch(:properties, []))
            end

            statistics.each do |_, stat|
              stat[:class_count] = stat.delete(:classes).size
              stat[:property_count] = stat.delete(:properties).size
            end

            statistics
          end

          def aggregate(gspo_count_result)
            stats = Hash.new { |h, k| h[k] = {} }

            File.open(gspo_count_result) do |f|
              gz = (Zlib::GzipReader.new(f) if File.extname(gspo_count_result) == '.gz')

              YAML.load_stream(gz || f) do |doc|
                doc['result'].each do |row|
                  graph = row['graph'] || row['_dummy']
                  head = row['head']&.to_sym
                  sclass = row['sclass']
                  pred = row['pred']
                  oclass = row['oclass']
                  dtype = row['dtype']
                  total = row['total'].to_i

                  case head
                  when :total_entity_count, :distinct_subject_count, :distinct_object_count
                    stats[graph][head] = total
                  when :distinct_class_entity_count
                    (stats[graph][head] ||= []) << {
                      class: sclass,
                      total: total
                    }
                  when :pred_count
                    (stats[graph][head] ||= []) << {
                      predicate: pred,
                      total: total
                    }
                  else
                    (stats[graph][:classes] ||= Set.new).add(sclass)
                    (stats[graph][:properties] ||= Set.new).add(pred)
                    ((stats[graph][:class_relations] ||= {})[pred] ||= []) << {
                      subject: sclass,
                      predicate: pred,
                      object: oclass,
                      dtype: dtype,
                      total: total
                    }
                  end
                end
              end
            ensure
              gz&.close
            end

            stats.deep_transform_values { |v| v.is_a?(Set) ? v.to_a : v }
          end

          def gspo(output)
            RDFPortal.logger.info(self.class) { "Graph clause is #{graph_disabled? ? 'disabled' : 'enabled'}." }

            list = datasets.flat_map do |dataset|
              query = if graph_disabled?
                        SPARQL::GSPO::QUERY_0_N
                      else
                        SPARQL::GSPO::QUERY_0_G.gsub('__graph__', "<#{dataset[:graph]}>")
                      end

              connection.fetch("SPARQL #{query}").flat_map do |row|
                if graph_disabled?
                  [
                    SPARQL::GSPO::QUERY_1_N.gsub('__sclass__', "<#{row[:class]}>"),
                    SPARQL::GSPO::QUERY_2_N.gsub('__oclass__', "<#{row[:class]}>"),
                    SPARQL::GSPO::QUERY_3_N.gsub('__sclass__', "<#{row[:class]}>")
                  ]
                else
                  [
                    SPARQL::GSPO::QUERY_1_G.gsub('__graph__', "<#{dataset[:graph]}>")
                                           .gsub('__sclass__', "<#{row[:class]}>"),
                    SPARQL::GSPO::QUERY_2_G.gsub('__graph__', "<#{dataset[:graph]}>")
                                           .gsub('__oclass__', "<#{row[:class]}>"),
                    SPARQL::GSPO::QUERY_3_G.gsub('__graph__', "<#{dataset[:graph]}>")
                                           .gsub('__sclass__', "<#{row[:class]}>")
                  ]
                end
              end
            end

            run_queries_in_parallel(sequence(list), output)
          end

          def gspo_count(gspo_input, output)
            list = []

            File.open(gspo_input) do |f|
              gz = (Zlib::GzipReader.new(f) if File.extname(gspo_input) == '.gz')

              graph_set = Set.new
              graph_class_set = Set.new
              graph_pred_set = Set.new

              YAML.load_stream(gz || f) do |doc|
                query = doc['query']
                is_dtype = query.include?('?dtype')

                doc['result'].each do |row|
                  next unless (graph = row['graph'] || row['_dummy'])

                  if graph_set.add?(graph)
                    list.concat(
                      if graph_disabled?
                        [
                          SPARQL::GSPO_COUNT::TOTAL_QN,
                          SPARQL::GSPO_COUNT::TOTAL_DS_QN,
                          SPARQL::GSPO_COUNT::TOTAL_DO_QN
                        ]
                      else
                        [
                          SPARQL::GSPO_COUNT::TOTAL_QG,
                          SPARQL::GSPO_COUNT::TOTAL_DS_QG,
                          SPARQL::GSPO_COUNT::TOTAL_DO_QG
                        ].map { |q| q.gsub('__graph__', "<#{graph}>") }
                      end
                    )
                  end

                  sclass = row['sclass']
                  pred = row['pred']

                  if graph_class_set.add?([graph, sclass])
                    list << if graph_disabled?
                              SPARQL::GSPO_COUNT::CLASS_QN.gsub('__sclass__', "<#{sclass}>")
                            else
                              SPARQL::GSPO_COUNT::CLASS_QG.gsub('__graph__', "<#{graph}>")
                                                          .gsub('__sclass__', "<#{sclass}>")
                            end
                  end

                  if graph_pred_set.add?([graph, pred])
                    list << if graph_disabled?
                              SPARQL::GSPO_COUNT::PRED_QN.gsub('__pred__', "<#{pred}>")
                            else
                              SPARQL::GSPO_COUNT::PRED_QG.gsub('__graph__', "<#{graph}>")
                                                         .gsub('__pred__', "<#{pred}>")
                            end
                  end

                  list << if is_dtype
                            if graph_disabled?
                              if (dtype = row['dtype']).present?
                                SPARQL::GSPO_COUNT::QUERY_DN.gsub('__sclass__', "<#{sclass}>")
                                                            .gsub('__pred__', "<#{pred}>")
                                                            .gsub('__dtype__', "<#{dtype}>")
                              else
                                SPARQL::GSPO_COUNT::QUERY_DN_NT.gsub('__sclass__', "<#{sclass}>")
                                                               .gsub('__pred__', "<#{pred}>")
                              end
                            elsif (dtype = row['dtype']).present?
                              SPARQL::GSPO_COUNT::QUERY_DG.gsub('__graph__', "<#{graph}>")
                                                          .gsub('__sclass__', "<#{sclass}>")
                                                          .gsub('__pred__', "<#{pred}>")
                                                          .gsub('__dtype__', "<#{dtype}>")
                            else
                              SPARQL::GSPO_COUNT::QUERY_DG_NT.gsub('__graph__', "<#{graph}>")
                                                             .gsub('__sclass__', "<#{sclass}>")
                                                             .gsub('__pred__', "<#{pred}>")
                            end
                          else
                            oclass = row['oclass']
                            if graph_disabled?
                              SPARQL::GSPO_COUNT::QUERY_CN.gsub('__sclass__', "<#{sclass}>")
                                                          .gsub('__pred__', "<#{pred}>")
                                                          .gsub('__oclass__', "<#{oclass}>")
                            else
                              SPARQL::GSPO_COUNT::QUERY_CG.gsub('__graph__', "<#{graph}>")
                                                          .gsub('__sclass__', "<#{sclass}>")
                                                          .gsub('__pred__', "<#{pred}>")
                                                          .gsub('__oclass__', "<#{oclass}>")
                            end
                          end
                end
              end
            ensure
              gz&.close
            end

            run_queries_in_parallel(sequence(list), output)
          end

          module Vocab
            NS = RDF::Vocabulary.new('http://rdfportal.org/ns/')
            SBM = RDF::Vocabulary.new('http://sparqlbuilder.org/2015/09/rdf-metadata-schema#')

            def self.prefixes
              {
                '': NS,
                owl: RDF::OWL,
                rdfs: RDF::RDFS,
                sbm: SBM,
                sd: RDF::Vocab::SD,
                void: RDF::Vocab::VOID,
                xsd: RDF::XSD
              }
            end
          end

          SPARQL_DEFAULT_GRAPH = Vocab::NS['sparql-default-graph']

          def void(gspo_count_input)
            RDF::Graph.new do |g|
              svcroot = Vocab::NS[:svcroot]
              root = Vocab::NS[:root]
              crawl_log = Vocab::NS[:crawlLog]

              g << [svcroot, RDF.type, RDF::Vocab::SD[:Service]]
              g << [svcroot, RDF::Vocab::SD[:defaultDataset], root]
              g << [root, RDF.type, RDF::Vocab::SD[:Dataset]]
              g << [root, Vocab::SBM[:crawlLog], crawl_log]
              g << [crawl_log, RDF.type, Vocab::SBM[:CrawlLog]]
              g << [crawl_log, Vocab::SBM[:crawlStartTime], RDF::Literal::DateTime.new(DateTime.now)]

              aggregate(gspo_count_input).each do |graph, stat|
                graph = Vocab::NS[hashed(graph)]

                if graph.start_with?('http')
                  g << [root, RDF::Vocab::SD[:defaultGraph], SPARQL_DEFAULT_GRAPH]
                  g << [SPARQL_DEFAULT_GRAPH, RDF.type, RDF::Vocab::SD[:Graph]]

                  g << [root, RDF::Vocab::SD[:namedGraph], graph]
                  g << [graph, RDF.type, RDF::Vocab::SD[:NamedGraph]]
                  g << [graph, RDF::Vocab::SD.name, RDF::URI(graph)]
                else
                  g << [root, RDF::Vocab::SD[:defaultGraph], graph]
                  g << [graph, RDF.type, RDF::Vocab::SD[:Graph]]
                end

                if (url = options.dig(:stat, :endpoint))
                  g << [graph, RDF::Vocab::SD[:endpoint], RDF::URI(url)]
                  g << [graph, RDF::Vocab::VOID[:sparqlEndpoint], RDF::URI(url)]
                end

                g << [graph, RDF::Vocab::SD[:graph], graph]
                g << [graph, RDF.type, RDF::Vocab::SD[:Graph]]
                g << [graph, RDF.type, RDF::Vocab::VOID[:Dataset]]

                if (v = stat[:total_entity_count])
                  g << [graph, RDF::Vocab::VOID[:triples], RDF::Literal::Integer.new(v.to_i)]
                end
                if (v = stat[:distinct_subject_count])
                  g << [graph, RDF::Vocab::VOID[:distinctSubjects], RDF::Literal::Integer.new(v.to_i)]
                end
                if (v = stat[:distinct_object_count])
                  g << [graph, RDF::Vocab::VOID[:distinctObjects], RDF::Literal::Integer.new(v.to_i)]
                end

                if (classes = stat[:classes]).present?
                  g << [graph, RDF::Vocab::VOID[:classes], RDF::Literal::Integer.new(classes.size)]

                  classes.each do |klass|
                    dataset = Vocab::NS[hashed(graph, klass, prefix: 'Class:')]
                    c = stat[:distinct_class_entity_count].find { |x| x[:class] == klass }&.fetch(:total) || 0

                    g << [graph, RDF::Vocab::VOID[:classPartition], dataset]
                    g << [dataset, RDF.type, RDF::Vocab::VOID[:Dataset]]
                    g << [dataset, RDF::Vocab::VOID[:class], RDF::URI(klass)]
                    g << [dataset, RDF::Vocab::VOID[:entities], RDF::Literal::Integer.new(c)]
                  end
                end

                if (properties = stat[:properties]).present?
                  g << [graph, RDF::Vocab::VOID[:properties], RDF::Literal::Integer.new(properties.size)]

                  properties.each do |property|
                    dataset = Vocab::NS[hashed(graph, property, prefix: 'Property:')]
                    c = stat[:pred_count].find { |x| x[:predicate] == property }&.fetch(:total) || 0

                    g << [graph, RDF::Vocab::VOID[:propertyPartition], dataset]
                    g << [dataset, RDF.type, RDF::Vocab::VOID[:Dataset]]
                    g << [dataset, RDF::Vocab::VOID[:property], RDF::URI(property)]
                    g << [dataset, RDF::Vocab::VOID[:triples], RDF::Literal::Integer.new(c)]
                  end
                end

                Array(stat[:class_relations]).each do |pred, xs|
                  dataset = Vocab::NS[hashed(graph, pred, prefix: 'Property:')]

                  xs.each do |x|
                    name = "#{x[:subject]}#{x[:predicate]}#{x[:object].presence || x[:dtype]}"
                    class_relation = Vocab::NS[hashed(graph, name, prefix: 'ClassRels:')]

                    g << [dataset, Vocab::SBM[:classRelation], class_relation]
                    g << [class_relation, RDF.type, Vocab::SBM[:ClassRelation]]
                    g << [class_relation, Vocab::SBM[:hashing], RDF::Literal.new("ClassRels:#{graph}#{name}", datatype: RDF::XSD.string)]
                    g << [class_relation, Vocab::SBM[:subjectClass], RDF::URI(x[:subject])]

                    g << if x[:dtype].present?
                           [class_relation, Vocab::SBM[:objectDatatype], x[:object] == 'None' ? RDF::XSD[:string] : RDF::URI(x[:dtype])]
                         else
                           [class_relation, Vocab::SBM[:objectClass], RDF::URI(x[:object])]
                         end

                    g << [class_relation, RDF::Vocab::VOID[:triples], RDF::Literal::Integer.new(x[:total])]
                  end
                end
              end
            end
          end

          def datasets
            return @datasets if @datasets

            datasets = options[:datasets].reject { |x| x.dig(:stat, :disable) == true }
                                         .flat_map { |x| RDFPortal.graph_config(x[:name]).map { |y| { name: x[:name], graph: y[:graph] } } }
                                         .uniq

            if graph_disabled? && datasets.size > 1
              raise Error, 'Multiple datasets are not allowed when trig is enabled.'
            end

            if (dup = datasets.group_by { |x| x[:graph] }.filter { |_, v| v.size > 1 }).any?
              dup.each do |k, v|
                RDFPortal.logger.warn(self.class) do
                  "#{v.map(&:dataset).uniq.join(', ')} are mapped to the same graph <#{k}>"
                end
              end
            end

            @datasets = datasets
          end

          private

          THREAD_TERMINATE_SIGNAL = :__END__
          private_constant :THREAD_TERMINATE_SIGNAL

          def graph_disabled?
            options.dig(:stat, :graph) == false
          end

          def hashed(graph, name = nil, prefix: nil)
            graph = "__dummy__#{self.name}" if graph_disabled?

            Digest::MD5.hexdigest("#{prefix}#{graph}#{name}")
          end

          def sequence(list)
            list.map.with_index do |query, i|
              replace = "  BIND('#{i + 1}/#{list.size}' AS ?seq)\n}"
              query.reverse.sub('}', replace.reverse).reverse
            end
          end

          # @return [Sequel::ODBC::Database]
          def connection
            Thread.current[:sequel_connection] ||= Sequel.connect(@adapter.connection.odbc_config)
          end

          def run_queries_in_parallel(queries, output, thread_count: 10)
            FileUtils.rm_f(output)

            write_buffer = Queue.new
            writer_thread = Thread.new do
              File.open(output, 'w') do |f|
                gz = if File.extname(output) == '.gz'
                       Zlib::GzipWriter.new(f, Zlib::BEST_COMPRESSION, Zlib::DEFAULT_STRATEGY)
                     end

                loop do
                  break if (chunk = write_buffer.pop) == THREAD_TERMINATE_SIGNAL

                  (gz || f).write(chunk)
                end

              ensure
                gz&.close
              end
            end

            parent_logger = RDFPortal.logger

            queue = Queue.new(queries + Array.new(thread_count, THREAD_TERMINATE_SIGNAL))
            threads = Array.new(thread_count) do
              Thread.new do
                RDFPortal.logger = parent_logger

                begin
                  loop do
                    break if (query = queue.pop) == THREAD_TERMINATE_SIGNAL

                    retry_count = 0
                    result = nil

                    t = Benchmark.realtime do
                      result = begin
                                 connection.fetch("SPARQL #{query.gsub(/\n\s*/, ' ').strip}").map(&:to_h)
                               rescue Sequel::DatabaseDisconnectError => e
                                 RDFPortal.logger.warn(self.class) { "#{e.message}, retrying..." }
                                 if (retry_count += 1) <= 3
                                   sleep 2**retry_count
                                   retry
                                 end
                                 raise e
                               rescue StandardError => e
                                 RDFPortal.logger.error(self.class) { e.full_message }
                                 [{ error: e.full_message }]
                               end
                    end

                    doc = { query:, elapsed: t.readable_duration, result: }.deep_stringify_keys.to_yaml

                    write_buffer << doc
                  end
                ensure
                  connection.disconnect
                end
              end
            end

            begin
              threads.each(&:join)
            rescue Interrupt => e
              RDFPortal.logger.warn(self.class) { 'Interrupted' }
              raise e
            ensure
              write_buffer << THREAD_TERMINATE_SIGNAL
              writer_thread.join
            end

            nil
          end
        end
      end
    end
  end
end
