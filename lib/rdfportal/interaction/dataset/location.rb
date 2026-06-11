# frozen_string_literal: true

module RDFPortal
  module Interaction
    module Dataset
      class Location < Base
        flex_array :url, default: nil do
          string
        end

        string :output, default: nil

        boolean :recursive, default: false

        flex_array :include, default: [] do
          string
        end

        flex_array :exclude, default: [] do
          string
        end

        hash :options, default: {}, strip: false

        validates :url, presence: true

        validate :url_config

        attr_reader :directory, :parameters, :continue, :no_incremental

        def initialize(inputs = {})
          @directory = inputs.delete(:directory)&.then { |d| Pathname.new(d) }
          @parameters = inputs.delete(:parameters) || {}
          @continue = inputs.delete(:continue)
          @no_incremental = inputs.delete(:no_incremental)

          if @parameters.present?
            %i[url output include exclude].each do |attribute|
              inputs = update_attribute(inputs.deep_symbolize_keys, attribute, parameters.symbolize_keys)
            end
          end

          super
        end

        # @return [Array<RDFPortal::Result>]
        def execute
          url.map do |location|
            RDFPortal.logger.info(self.class) { "Download from #{location}" }

            if output && (dir = File.dirname(output)) != '.'
              FileUtils.mkdir_p(dir)
            end

            downloader = Downloader.new(url: location,
                                        output:,
                                        recursive:,
                                        include:,
                                        exclude:,
                                        **options.deep_symbolize_keys,
                                        continue:,
                                        no_incremental:,
                                        pretend:,
                                        pretend_output:,
                                        directory:)

            t, ret = Benchmark.realtime_with_return do
              if options[:force_ftp]
                downloader.lftp
              else
                case URI(location)
                when URI::HTTP, URI::HTTPS
                  downloader.wget
                when URI::FTP
                  downloader.lftp
                when URI::File
                  downloader.rsync
                when URI::Generic
                  raise Error, 'Invalid URI' unless URI(location).scheme == 'rsync'

                  downloader.rsync
                else
                  raise Error, 'Invalid URI'
                end
              end
            end

            RDFPortal.logger.info(self.class) { "Finished in #{t.readable_duration}" }

            ret
          rescue StandardError => e
            RDFPortal.logger.error(self.class) { e.full_message }

            abort(e.message) if pretend

            Result.new(:error, "Fetch #{location}", e.full_message)
          end
        end

        private

        def url_config
          return if url.blank?

          errors.add(:url, 'must be single value if `output` is given') if url.size > 1 && output

          errors.add(:url, 'must be single value if `recursive` is enabled') if url.size > 1 && recursive

          url.each_with_index do |x, i|
            attribute = raw_input(:url).is_a?(Array) ? "url[#{i}]" : :url

            if options[:force_ftp] && !%r{\Ahttps?://}.match?(x)
              errors.add(attribute, 'must start with "http://" or "https://"')
            end

            if !options[:force_ftp] && !%r{\A(https?|ftp|rsync|file)://}.match?(x)
              errors.add(attribute, 'must start with "http://", "https://", "ftp://", "rsync://" or "file://"')
            end
          end
        end

        def update_attribute(inputs, attribute, hash)
          return inputs unless (value = inputs[attribute])

          inputs.merge(attribute => format_value(value, hash))
        end

        def format_value(value, hash)
          if value.is_a?(Array)
            value.map { |v| format_value(v, hash) }
          else
            format(value, hash)
          end
        end
      end
    end
  end
end
