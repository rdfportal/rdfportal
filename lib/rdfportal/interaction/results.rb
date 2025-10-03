# frozen_string_literal: true

module RDFPortal
  module Interaction
    class Results < Hash
      PADDING_SIZE = 2

      attr_reader :directory_prefix

      def initialize(directory_prefix)
        super()
        @directory_prefix = directory_prefix.to_s
      end

      def success?(key = nil)
        if key
          Array(fetch(key)).all? { |x| x.success? || x.skipped? }
        else
          keys.all? { |k| success?(k) }
        end
      end

      def failure?(key = nil)
        if key
          Array(fetch(key)).all? { |x| x.failure? || x.error? }
        else
          keys.all? { |k| failure?(k) }
        end
      end

      def skipped?(key = nil)
        if key
          Array(fetch(key)).any?(&:skipped?)
        else
          keys.all? { |k| skipped?(k) }
        end
      end

      def to_s
        pretty_format(self)
      end

      private

      def pretty_format(obj, indent = 0)
        output = StringIO.new

        case obj
        when Hash
          obj.each do |key, value|
            output.puts key
            output.puts pretty_format(value, indent + 1)
          end
        when Array
          obj.each do |x|
            output.puts pretty_format(x)
          end
        else
          output.puts obj.to_s
          output.puts
        end

        output.string.indent(PADDING_SIZE * indent)
      end
    end
  end
end
