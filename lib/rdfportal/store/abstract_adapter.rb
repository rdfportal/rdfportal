# frozen_string_literal: true

module RDFPortal
  module Store
    class AbstractAdapter
      attr_reader :name, :repository, :options

      def initialize(name, repository, **options)
        @name = name
        @repository = repository
        @options = options
      end

      def server_running?
        raise NotImplementedError
      end

      def start_if_needed!
        raise NotImplementedError
      end

      def stop!
        raise NotImplementedError
      end

      def setup(**options)
        raise NotImplementedError
      end

      def status
        raise NotImplementedError
      end

      def setup_loader(**options)
        raise NotImplementedError
      end

      def cleanup_loader(**options)
        raise NotImplementedError
      end

      def before_load(**options)
        raise NotImplementedError
      end

      def exec_load(**options)
        raise NotImplementedError
      end

      def after_load(**options)
        raise NotImplementedError
      end

      def publish(**options)
        raise NotImplementedError
      end

      def environment(**options)
        raise NotImplementedError
      end

      def statistics(**options)
        raise NotImplementedError
      end

      private

      def datasets
        return @datasets if @datasets

        datasets = options[:datasets].reject { |x| x.dig(:stat, :disable) == true }
                                     .flat_map { |x| RDFPortal.graph_config(x[:name]).map { |y| { name: x[:name], graph: y[:graph] } } }
                                     .uniq

        if stat_graph_disabled? && datasets.size > 1
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

      def stat_graph_disabled?
        options.dig(:stat, :graph) == false
      end
    end
  end
end
