# frozen_string_literal: true

module RDFPortal
  module Interaction
    module Dataset
      class Fetch < Base
        hash :directory, default: -> { {} } do
          string :prefix, default: -> { RDFPortal.datasets_dir.join(name).to_s }
        end

        integer :preserve, default: 5

        hash :parameters, default: {}, strip: false

        flex_array :datasets do
          hash strip: false
        end

        validates :name, presence: true

        validates :datasets, presence: true

        validate :datasets_config

        validate :parameters_config

        attr_reader :name, :continue, :no_incremental

        def initialize(inputs = {})
          @name = inputs.delete(:name)
          @continue = inputs.delete(:continue)
          @no_incremental = inputs.delete(:no_incremental)

          super
        end

        # @return [RDFPortal::Interaction::Results]
        def execute
          RDFPortal.logger.info(self.class) { "Directory prefix = #{directory_prefix}" }

          result = Results.new(directory_prefix)

          t = Benchmark.realtime do
            if (parameters = resolve_parameters).present?
              RDFPortal.logger.info(self.class) { "Parameters resolved as: #{parameters.inspect}" }

              pretend_output.puts "Parameters: #{parameters}" if pretend
            end

            datasets.each do |hash|
              key = if hash[:group]
                      hash[:group] = format(hash[:group], parameters.symbolize_keys)
                      "#{directory_prefix.basename}/#{hash[:group]}"
                    else
                      directory_prefix.basename.to_s
                    end

              inputs = {
                preserve:,
                **hash,
                directory: directory_prefix,
                parameters:,
                continue:,
                no_incremental:,
                pretend:
              }

              result[key] = compose(DatasetGroup, **inputs).flatten
            end
          end

          RDFPortal.logger.info(self.class) { "Completed in #{t.readable_duration}" }

          result
        end

        private

        # @return [Pathname]
        def directory_prefix
          @directory_prefix ||= Pathname.new(directory[:prefix])
                                        .expand_path
                                        .tap { |dir| dir.mkpath unless dir.exist? }
                                        .realpath
        end

        def parameters_config
          parameters.each do |key, config|
            next if (parameter = Parameter.new(config)).valid?

            parameter.errors.each do |error|
              errors.import(error, attribute: "parameters.#{key}.#{error.attribute}")
            end
          end
        end

        def datasets_config
          return if datasets.blank?

          groups = {}

          datasets.each_with_index do |hash, i|
            (groups[hash[:group]] ||= []).push(i)

            next if (group = DatasetGroup.new(**hash, directory: directory_prefix, preserve:, continue:, pretend:)).valid?

            attribute = raw_input(:datasets).is_a?(Array) ? "datasets[#{i}]" : :datasets

            group.errors.each do |error|
              errors.import(error, attribute: "#{attribute}.#{error.attribute}")
            end
          end

          errors.add(:datasets, 'both non-grouped and grouped dataset defined') if groups.key?(nil) && groups.size > 1

          groups.filter { |_, v| v.size >= 2 }.each_value do |v|
            v.each do |i|
              errors.add("datasets[#{i}].group", 'duplicated group')
            end
          end
        end

        def resolve_parameters
          return if parameters.blank?

          RDFPortal.logger.info(self.class) { 'Resolving parameters...' }

          parameters.transform_values { |parameter| compose(Parameter, **parameter) }
        end
      end
    end
  end
end
