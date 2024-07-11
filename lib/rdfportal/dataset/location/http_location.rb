# frozen_string_literal: true

module RDFPortal
  module Dataset
    class Location
      class HTTPLocation < Location
        LOG_NAME = 'HTTP LOCATION'

        def list_contents(directory: true, file: true)
          http_opts = { followlocation: true, headers: { accept: 'text/html' } }.merge(Hash(@options[:http]))

          @uri = resolve_location(@uri, **http_opts)

          if !@uri.path.to_s.end_with?('/') && @options[:recursive].blank? && @options[:includes].blank?
            return [] unless file

            options = @options.merge(output_file_name: @options[:output])
            content = Content::HTTPContent.new(@uri, Content::TYPE::FILE, **options)

            return [content]
          end

          res = Typhoeus.get(@uri, **http_opts)
          RDFPortal.logger.debug(LOG_NAME) { res.body }

          elems = Nokogiri::HTML.parse(res.response_body, @options[:encoding]).css('body a[href]')
          elems.filter_map do |elem|
            next if (href = elem[:href]).match?(%r{^https?://}) && (URI(href).host != @uri.host)
            next if href.match?(%r{^/$}) || href.match?(/^\./) || href.match?(/[?&]/)

            uri = @uri.dup.tap { |x| x.path = join(href).path.to_s }
            relative_path = relative_path(uri)

            output_base_path = if @options[:output].present?
                                 Pathname.new(@options[:output]).join(relative_path).dirname.to_s
                               else
                                 Pathname.new(relative_path).dirname
                               end
            options = @options.merge(output_base_path:)

            if uri.path.end_with?('/')
              next unless directory
              next if elem.text&.match?(/parent directory/i)

              Content::HTTPContent.new(uri, Content::TYPE::DIRECTORY, **options)
            else
              next unless file

              basename = File.basename(uri.path.to_s)
              next if @options[:includes].present? && @options[:includes].none? { |re| re.match?(basename) }

              Content::HTTPContent.new(uri, Content::TYPE::FILE, **options)
            end
          end
        end

        private

        def resolve_location(uri, **options)
          res = Typhoeus.head(uri, **options)

          URI(res.effective_url)
        end
      end
    end
  end
end
