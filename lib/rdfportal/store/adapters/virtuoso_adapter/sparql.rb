# frozen_string_literal: true

module RDFPortal
  module Store
    module Adapters
      class VirtuosoAdapter
        class Statistics
          module SPARQL
            DUMMY_HEAD = '("__dummy__" AS ?_dummy)'

            EXCLUDE_GRAPH = <<~SPARQL
              NOT FROM <http://www.openlinksw.com/schemas/virtrdf#>
              NOT FROM <http://www.w3.org/ns/ldp#>
              NOT FROM <urn:activitystreams-owl:map>
              NOT FROM <http://localhost:8890/sparql>
              NOT FROM <http://localhost:8890/DAV/>
              NOT FROM <http://www.w3.org/2002/07/owl#>
            SPARQL

            module GSPO
              QUERY_0_G = <<~SPARQL
                SELECT DISTINCT ?graph ?class {
                  VALUES ?graph { __graph__ }
                  GRAPH ?graph {
                    [] a ?class .
                  }
                }
              SPARQL

              QUERY_0_N = <<~SPARQL.freeze
                SELECT DISTINCT ("__dummy__" AS ?_dummy) ?class
                #{EXCLUDE_GRAPH.strip}
                {
                  [] a ?class .
                }
              SPARQL

              QUERY_1_G = <<~SPARQL
                SELECT DISTINCT ?graph ?sclass ?pred ?oclass {
                  VALUES (?graph ?sclass) { (__graph__ __sclass__) }
                  GRAPH ?graph {
                    [a ?sclass] ?pred [a ?oclass] .
                  }
                }
              SPARQL

              QUERY_1_GR = <<~SPARQL
                SELECT DISTINCT ?graph ?sclass ?pred ?oclass {
                  VALUES (?graph ?sclass ?oclass) { (__graph__ __sclass__ __oclass__) }
                  GRAPH ?graph {
                    [a ?sclass] ?pred [a ?oclass] .
                  }
                }
              SPARQL

              QUERY_1_N = <<~SPARQL.freeze
                SELECT DISTINCT ("__dummy__" AS ?_dummy) ?sclass ?pred ?oclass
                #{EXCLUDE_GRAPH.strip}
                {
                  VALUES ?sclass { __sclass__ }
                  [a ?sclass] ?pred [a ?oclass] .
                }
              SPARQL

              QUERY_1_NR = <<~SPARQL.freeze
                SELECT DISTINCT ("__dummy__" AS ?_dummy) ?sclass ?pred ?oclass
                #{EXCLUDE_GRAPH.strip}
                {
                  VALUES ?sclass ?oclass { __sclass__ __oclass__ }
                  [a ?sclass] ?pred [a ?oclass] .
                }
              SPARQL

              QUERY_2_G = <<~SPARQL
                SELECT DISTINCT ?graph ?sclass ?pred ?oclass {
                  VALUES (?graph ?oclass) { (__graph__ __oclass__) }
                  GRAPH ?graph {
                    [a ?sclass] ?pred [a ?oclass] .
                  }
                }
              SPARQL

              QUERY_2_N = <<~SPARQL.freeze
                SELECT DISTINCT ("__dummy__" AS ?_dummy) ?sclass ?pred ?oclass
                #{EXCLUDE_GRAPH.strip}
                {
                  VALUES ?oclass { __oclass__ }
                  [a ?sclass] ?pred [a ?oclass] .
                }
              SPARQL

              QUERY_3_G = <<~SPARQL
                SELECT DISTINCT ?graph ?sclass ?pred ?dtype {
                  VALUES ?graph { __graph__ }
                  VALUES ?sclass { __sclass__ }
                  GRAPH ?graph {
                    [a ?sclass] ?pred ?obj .
                    FILTER isliteral(?obj)
                    BIND (datatype(?obj) AS ?dtype)
                  }
                }
              SPARQL

              QUERY_3_N = <<~SPARQL.freeze
                SELECT DISTINCT ("__dummy__" AS ?_dummy) ?sclass ?pred ?dtype
                #{EXCLUDE_GRAPH.strip}
                {
                  VALUES ?sclass { __sclass__ }
                  [a ?sclass] ?pred ?obj .
                  FILTER isliteral(?obj)
                  BIND (datatype(?obj) AS ?dtype)
                }
              SPARQL
            end

            module GSPO_COUNT
              TOTAL_QG = <<~SPARQL
                SELECT ?graph ("total_entity_count" AS ?head) (STR(COUNT(*)) AS ?total) {
                  VALUES ?graph { __graph__ }
                  GRAPH ?graph {
                    ?s ?p ?o .
                  }
                }
              SPARQL

              TOTAL_QN = <<~SPARQL.freeze
                SELECT #{DUMMY_HEAD} ("total_entity_count" AS ?head) (STR(COUNT(*)) AS ?total)
                #{EXCLUDE_GRAPH.strip}
                {
                  ?s ?p ?o .
                }
              SPARQL

              TOTAL_DS_QG = <<~SPARQL
                SELECT ?graph ("distinct_subject_count" AS ?head) (STR(COUNT(DISTINCT ?s)) AS ?total) {
                  VALUES ?graph { __graph__ }
                  GRAPH ?graph {
                    ?s ?p ?o .
                  }
                }
              SPARQL

              TOTAL_DS_QN = <<~SPARQL.freeze
                SELECT #{DUMMY_HEAD} ("distinct_subject_count" AS ?head) (STR(COUNT(DISTINCT ?s)) AS ?total)
                #{EXCLUDE_GRAPH.strip}
                {
                  ?s ?p ?o .
                }
              SPARQL

              TOTAL_DO_QG = <<~SPARQL
                SELECT ?graph ("distinct_object_count" AS ?head) (STR(COUNT(DISTINCT ?o)) AS ?total) {
                  VALUES ?graph { __graph__ }
                  GRAPH ?graph {
                    ?s ?p ?o .
                  }
                }
              SPARQL

              TOTAL_DO_QN = <<~SPARQL.freeze
                SELECT #{DUMMY_HEAD} ("distinct_object_count" AS ?head) (STR(COUNT(DISTINCT ?o)) AS ?total)
                #{EXCLUDE_GRAPH.strip}
                {
                  ?s ?p ?o .
                }
              SPARQL

              CLASS_QG = <<~SPARQL
                SELECT ?graph ("distinct_class_entity_count" AS ?head) ?sclass (STR(COUNT(DISTINCT ?s)) AS ?total) {
                  VALUES (?graph ?sclass) { ( __graph__ __sclass__ ) }
                  GRAPH ?graph {
                    ?s a ?sclass .
                  }
                }
              SPARQL

              CLASS_QN = <<~SPARQL.freeze
                SELECT #{DUMMY_HEAD} ("distinct_class_entity_count" AS ?head) ?sclass (STR(COUNT(DISTINCT ?s)) AS ?total)
                #{EXCLUDE_GRAPH.strip}
                {
                  VALUES ?sclass { __sclass__ }
                  ?s a ?sclass .
                }
              SPARQL

              PRED_QG = <<~SPARQL
                SELECT ?graph ("pred_count" AS ?head) ?pred (STR(COUNT(?pred)) AS ?total) {
                  VALUES (?graph ?pred) { ( __graph__ __pred__ ) }
                  GRAPH ?graph {
                    ?s ?pred ?o .
                  }
                }
              SPARQL

              PRED_QN = <<~SPARQL.freeze
                SELECT #{DUMMY_HEAD} ("pred_count" AS ?head) ?pred (STR(COUNT(?pred)) AS ?total)
                #{EXCLUDE_GRAPH.strip}
                {
                  VALUES ?pred { __pred__ }
                  ?s ?pred ?o .
                }
              SPARQL

              QUERY_CG = <<~SPARQL
                SELECT ?graph ?sclass ?pred ?oclass (STR(COUNT(?pred)) AS ?total) {
                  VALUES (?graph ?sclass ?pred ?oclass) { ( __graph__ __sclass__ __pred__ __oclass__ ) }
                  GRAPH ?graph {
                    [ a ?sclass ] ?pred [ a ?oclass ] .
                  }
                }
                GROUP BY ?graph ?sclass ?pred ?oclass
              SPARQL

              QUERY_CN = <<~SPARQL.freeze
                SELECT #{DUMMY_HEAD} ?sclass ?pred ?oclass (STR(COUNT(?pred)) AS ?total)
                #{EXCLUDE_GRAPH.strip}
                {
                  VALUES (?sclass ?pred ?oclass) { ( __sclass__ __pred__ __oclass__ ) }
                  [ a ?sclass ] ?pred [ a ?oclass ] .
                }
                GROUP BY ?sclass ?pred ?oclass
              SPARQL

              QUERY_DG = <<~SPARQL
                SELECT ?graph ?sclass ?pred ?dtype (STR(COUNT(?pred)) AS ?total) {
                  VALUES (?graph ?sclass ?pred ?dtype) { ( __graph__ __sclass__ __pred__ __dtype__ ) }
                  GRAPH ?graph {
                    [ a ?sclass ] ?pred ?obj .
                  }
                  FILTER (isLiteral(?obj) and datatype(?obj) = ?dtype)
                }
                GROUP BY ?graph ?sclass ?pred ?dtype
              SPARQL

              QUERY_DN = <<~SPARQL.freeze
                SELECT #{DUMMY_HEAD} ?sclass ?pred ?dtype (STR(COUNT(?pred)) AS ?total)
                #{EXCLUDE_GRAPH.strip}
                {
                  VALUES (?sclass ?pred ?dtype) { ( __sclass__ __pred__ __dtype__ ) }
                  [ a ?sclass ] ?pred ?obj .
                  FILTER (isLiteral(?obj) and datatype(?obj) = ?dtype)
                }
                GROUP BY ?sclass ?pred ?dtype
              SPARQL

              QUERY_DG_NT = <<~SPARQL
                SELECT ?graph ?sclass ?pred ("None" AS ?dtype) (STR(COUNT(?pred)) AS ?total) {
                  VALUES (?graph ?sclass ?pred) { ( __graph__ __sclass__ __pred__ ) }
                  GRAPH ?graph {
                    [ a ?sclass ] ?pred ?obj .
                  }
                  FILTER isLiteral(?obj)
                }
                GROUP BY ?graph ?sclass ?pred
              SPARQL

              QUERY_DN_NT = <<~SPARQL.freeze
                SELECT #{DUMMY_HEAD} ?sclass ?pred ("None" AS ?dtype) (STR(COUNT(?pred)) AS ?total)
                #{EXCLUDE_GRAPH.strip}
                {
                  VALUES (?sclass ?pred) { ( __sclass__ __pred__ ) }
                  [ a ?sclass ] ?pred ?obj .
                  FILTER isLiteral(?obj)
                }
                GROUP BY ?sclass ?pred
              SPARQL
            end
          end
        end
      end
    end
  end
end
