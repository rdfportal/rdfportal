# frozen_string_literal: true

module RDFPortal
  module CLI
    class Generate < Thor
      include Thor::Actions

      class << self
        def exit_on_failure?
          true
        end

        def source_root
          TEMPLATE_DIR
        end
      end

      desc 'dataset <name> [sub group] [sub group] ...', 'Generate dataset template'
      option :pretend, type: :boolean, aliases: '-p', desc: 'Run but do not generate actually'

      def dataset(name, *datasets)
        inside(config_dir.join(DATASETS_DIR_NAME)) do
          run("mkdir -p #{name}")

          inside(name) do
            @name = name
            @datasets = datasets
            template(File.join(TEMPLATE_DIR, 'dataset.yml.erb'), DATASET_FILE_NAME)
            template(File.join(TEMPLATE_DIR, 'graph.tsv.erb'), GRAPH_FILE_NAME)
          end
        end
      end

      desc 'endpoint <name> [dataset] [dataset] ...', 'Generate endpoint template'
      option :pretend, type: :boolean, aliases: '-p', desc: 'Run but do not generate actually'

      def endpoint(name, *datasets)
        datasets.each do |dataset|
          next if config_dir.join(DATASETS_DIR_NAME, dataset).exist?

          warn "Configuration does not exist: #{dataset}"
          warn "Please try this command first: `rdfportal generate dataset #{dataset}`"
          exit 1
        end

        inside(config_dir.join(ENDPOINTS_DIR_NAME)) do
          @name = name
          @datasets = datasets
          template(File.join(TEMPLATE_DIR, 'endpoint.yml.erb'), "#{name}.yml")
        end
      end

      private

      def repository
        @repository ||= Repository.new
      end

      def config_dir
        Pathname.new(RDFPortal.config_dir)
      end
    end
  end
end
