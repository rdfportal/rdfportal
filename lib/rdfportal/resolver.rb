# frozen_string_literal: true

module RDFPortal
  class Resolver
    PLACEHOLDER_REGEXP = /%\{[\w\-.]+}/

    class << self
      def env(name)
        ENV.fetch(name)
      end

      def location(url, **options)
        entries = Resource.parse(url)
                                 .list(**options)
                                 .delete_if { |x| options[:type].present? && options[:type].to_sym != x.type }
                                 .to_h { |x| [x, { basename: x.basename }] }

        raise Error, 'No entries found' if entries.blank?

        RDFPortal.logger.debug(self) { "Entries = #{entries.values.map { |x| x[:basename] }}" }

        if options[:match]
          RDFPortal.logger.debug(self) { "Matcher = #{options[:match]}" }

          entries.each_value do |x|
            x[:capture] = begin
                            if options[:capture].is_a?(Integer)
                              x[:basename][options[:match], options[:capture]]
                            elsif options[:capture].is_a?(Array) && options[:capture].size == 1
                              x[:basename][options[:match], options[:capture][0]]
                            else
                              next unless (v = options[:capture].map { |i| x[:basename][options[:match], i] }).all?

                              format(options[:test], *v)
                            end
                          rescue StandardError
                            nil
                          end
          end

          entries.filter! { |_, v| v[:capture].present? }

          raise Error, 'No match parameter found' if entries.blank?

          RDFPortal.logger.debug(self) { "Match result = #{entries.values.map { |x| x[:capture] }}" }
        end

        if options[:sort]
          RDFPortal.logger.debug(self) { "Sorter = #{options[:sort]}" }

          entries.each_value do |x|
            str = options[:match] ? x[:capture] : x[:basename]
            x[:sort] = case options[:sort]
                       when 'datetime'
                         begin
                           DateTime.parse(str)
                         rescue StandardError
                           RDFPortal.logger.warn(self) { "Failed to parse datetime: #{str}" }
                           nil
                         end
                       when 'version'
                         begin
                           Gem::Version.new(str.gsub(/\D+/, '.')[/(#{Gem::Version::VERSION_PATTERN})/o, 0])
                         rescue StandardError
                           RDFPortal.logger.warn(self) { "Failed to parse version: #{str}" }
                           nil
                         end
                       when 'numerical'
                         begin
                           Integer(str)
                         rescue StandardError
                           RDFPortal.logger.warn(self) { "Failed to parse integer: #{str}" }
                           nil
                         end
                       else
                         str
                       end
          end

          entries.filter! { |_, v| v[:sort].present? }

          raise Error, 'No sortable parameter found' if entries.blank?

          RDFPortal.logger.debug(self) { "Sort = #{entries.values.map { |x| x[:sort] }}" }
        end

        entry, value = entries.send(options[:order] == 'asc' ? :min_by : :max_by) do |_, v|
          if options[:sort]
            v[:sort]
          elsif options[:match]
            v[:capture]
          else
            v[:basename]
          end
        end

        if options[:return] == 'basename'
          entry.basename
        elsif options[:match]
          value[:capture]
        else
          value[:basename]
        end
      end
    end
  end
end
