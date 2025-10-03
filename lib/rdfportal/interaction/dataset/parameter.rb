# frozen_string_literal: true

module RDFPortal
  module Interaction
    module Dataset
      class Parameter < Base
        require 'rdfportal/matcher'

        string :env, default: nil

        string :url, default: nil

        hash :options, default: {} do
          hash :http, default: nil, strip: false
          hash :ftp, default: nil, strip: false
          string :encoding, default: nil # passed to Nokogiri::HTML.parse
        end

        string :type, default: nil

        object :match, default: nil, class: RDFPortal::Matcher, converter: :new

        flex_array :capture, default: [0] do
          integer
        end

        string :test, default: '%s'

        string :sort, default: 'alphabetical'

        string :order, default: 'asc'

        string :return, default: nil

        validate do
          next if env.present? || url.present?

          errors.add :base, :invalid, message: 'Missing required key: env or url'
        end

        validate(if: -> { env.present? }) do
          next if ENV.key?(env)

          errors.add(:env, :invalid, message: "`#{env}` is not defined")
        end

        validates :type,
                  inclusion: { in: %w[directory file], message: '%<value>s is invalid' },
                  if: -> { url.present? && type.present? }
        validates :match, presence: true, if: -> { url.present? }
        validates :sort,
                  inclusion: { in: %w[alphabetical datetime numerical version], message: '%<value>s is invalid' },
                  if: -> { url.present? }
        validates :order,
                  inclusion: { in: %w[asc desc], message: '%<value>s is invalid' },
                  if: -> { url.present? }
        validates :return,
                  inclusion: { in: %w[basename] },
                  if: -> { inputs[:return].present? }

        def execute
          return RDFPortal::Resolver.env(env) if env

          RDFPortal::Resolver.location(url, type:, match:, capture:, test:, sort:, order:, return:, **options)
        end
      end
    end
  end
end
