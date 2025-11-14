# frozen_string_literal: true

require 'active_interaction'
require 'active_model'
require 'benchmark'
require 'sequel'
require 'tty-command'

module ActiveInteraction
  class FlexibleArrayFilter < ArrayFilter
    register :flex_array

    TRANSLATIONS = {
      active_interaction: {
        types: {
          flex_array: 'flex_array'
        }
      }
    }.freeze

    I18n.backend.store_translations(:en, TRANSLATIONS)

    def cast(value, context, convertize: true, reconstantize: true)
      return nil if value.nil?

      value = [value] unless value.is_a?(Array)

      super
    end
  end
end

module ActiveModel
  module NestedAttributeError
    def input_error_messages
      io = StringIO.new

      messages.each do |key, messages|
        io.puts "#{key}:"
        messages.each do |message|
          io.puts "  - #{message}"
        end
      end

      io.string
    end
  end

  Errors.prepend(NestedAttributeError)

  module PrepareNestedAttribute
    def prepare_value_for_validation(value, record, attr_name)
      if attr_name.to_s.include?('.')
        nested_keys = attr_name.to_s.split('.').map(&:to_sym).drop(1)
        value = value.dig(*nested_keys)
      end

      super
    end
  end

  EachValidator.prepend(PrepareNestedAttribute)

  module Validations
    module Existent
      def exist?(path)
        Pathname.new(path).exist?
      end
    end

    class ExistenceValidator < EachValidator
      include Existent

      def validate_each(record, attribute, value)
        return if exist?(value)

        record.errors.add(attribute, :existence, message: "is not found - #{value}", **options)
      end
    end

    class NonExistenceValidator < EachValidator
      include Existent

      def validate_each(record, attribute, value)
        return unless exist?(value)

        record.errors.add(attribute, :non_existence, message: "already exists - #{value}", **options)
      end
    end

    class ArrayInclusionValidator < EachValidator
      def validate_each(record, attribute, value)
        return if value.blank?

        unless value.is_a?(Array)
          record.errors.add(attribute, 'must be an array')
          return
        end

        if (invalid = value.reject { |v| Array(options[:in]).include?(v) }).any?
          record.errors.add(attribute, "includes invalid #{'value'.pluralize(invalid.size)}: #{invalid.join(', ')}")
        end
      end
    end
  end
end

module Benchmark
  def realtime_with_return
    r0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ret = yield
    [Process.clock_gettime(Process::CLOCK_MONOTONIC) - r0, ret]
  end

  module_function :realtime_with_return
end

module TTY
  class Command
    class Result
      attr_accessor :command
    end
  end
end

class Integer
  def readable_duration
    s = self % 60
    m = (self / 60.0).to_i % 60
    h = (self / 60.0 / 60.0).to_i % 24
    d = (self / 60.0 / 60.0 / 24.0).to_i

    "#{"#{d}d " if d.positive?}#{format('%<h>02d:%<m>02d:%<s>02d', { h:, m:, s: })}"
  end
end

class Float
  def readable_duration
    return to_i.readable_duration if self > 60.0

    "#{round(3)}s"
  end
end
