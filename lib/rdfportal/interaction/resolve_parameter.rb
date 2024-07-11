# frozen_string_literal: true

require 'rdfportal/matcher'

module RDFPortal
  module Interaction
    class ResolveParameter < ActiveInteraction::Base
      LOG_NAME = 'RESOLVE_PARAMS'

      string :env, default: nil

      string :location, default: nil
      string :type, default: nil
      object :match, default: nil, class: RDFPortal::Matcher, converter: :new
      integer :capture, default: 0
      string :sort, default: 'alphabetical'
      string :order, default: 'asc'

      validate do
        next if env.present? || location.present?

        errors.add :base, :invalid, message: 'Missing required key: env or location'
      end

      validates :type,
                inclusion: { in: %w[directory file], message: '%<value>s is invalid' },
                if: -> { location.present? && type.present? }
      validates :match, presence: true, if: -> { location.present? }
      validates :capture, numericality: { only_integer: true }, if: -> { location.present? }
      validates :sort,
                inclusion: { in: %w[alphabetical datetime numerical version], message: '%<value>s is invalid' },
                if: -> { location.present? }
      validates :order,
                inclusion: { in: %w[asc desc], message: '%<value>s is invalid' },
                if: -> { location.present? }

      def execute
        if env.present?
          resolve_env
        else
          resolve_location
        end
      end

      private

      def resolve_env
        ENV.fetch(env)
      rescue KeyError
        errors.add(:base, :invalid, message: "Environment variable #{env} is not defined")
      end

      def resolve_location
        location = Dataset::Location.open(self.location, recursive: false)
        directory = type.blank? || type == 'directory'
        file = type.blank? || type == 'file'

        contents = location.list(directory:, file:)
                           .filter_map { |x| x.uri.to_s[match, capture] }

        case sort
        when 'version'
          contents.sort_by! { |x| Gem::Version.new(x.gsub(/\D+/, '.')[/(#{Gem::Version::VERSION_PATTERN})/o, 0]) }
        when 'numeric'
          contents.sort_by! { |x| Integer(x, exception: false) }
        else
          contents.sort!
        end

        order == 'asc' ? contents.first : contents.last
      end
    end
  end
end
