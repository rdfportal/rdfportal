# frozen_string_literal: true

require 'rdfportal/matcher'

module RDFPortal
  module Interaction
    class ListContents < Base
      string :location

      string :output, default: nil

      boolean :recursive, default: false

      array :includes, default: [] do
        object class: RDFPortal::Matcher, converter: :new
      end

      hash :parameters, default: {}, strip: false

      hash :options, default: {} do
        hash :http, default: nil, strip: false
      end

      validates :output,
                absence: { message: 'must be blank if `recursive` or `includes` is set' },
                if: -> { recursive.present? || includes.present? }

      LOG_NAME = 'LIST CONTENTS'

      def execute
        params = parameters.to_h do |k, param|
          ret = ResolveParameter.run(param)

          unless ret.valid?
            e = InvalidConfigurationError.new(ret.errors.full_messages.join(', '))
            e.input = { k => param }
            raise e
          end

          [k.to_sym, ret.result]
        end

        RDFPortal.logger.debug(LOG_NAME) { "Params = #{params}" }

        uri = URI.parse(format(location, params))
        opts = options.merge(output:, recursive:, includes:)

        RDFPortal.logger.debug(LOG_NAME) { "URI = \"#{uri}\", options = #{opts}" }

        (location = Dataset::Location.open(uri, **opts)) ? location.list(directory: false) : []
      end
    end
  end
end
