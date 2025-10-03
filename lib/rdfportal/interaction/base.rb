# frozen_string_literal: true

module RDFPortal
  module Interaction
    class Base < ActiveInteraction::Base
      attr_reader :pretend

      def initialize(inputs = {})
        @pretend = inputs.delete(:pretend)
        super
      end

      def config
        inputs.to_h.compact_blank.deep_transform_values { |v| v.respond_to?(:config) ? v.config.compact_blank : v }
      end

      private

      def raw_input(symbol)
        @_interaction_raw_inputs.with_indifferent_access[symbol]
      end

      def pretend_output
        Interaction.pretend_output
      end
    end

    THREAD_KEY = :rdfportal_pretend_output

    def self.pretend_output
      Thread.current[THREAD_KEY] ||= PretendOutput.new
    end

    def self.reset_pretend_output!
      Thread.current[THREAD_KEY] = nil
    end

    class PretendOutput < StringIO
      PADDING_SIZE = 2

      attr_accessor :padding

      def initialize(out = $stdout)
        super()
        @padding = 0
        @out = out
      end

      alias to_s string

      def with_indent(padding = 1)
        @padding += padding

        yield self
      ensure
        @padding -= padding
      end

      def write(string, *args)
        str = string.indent(PADDING_SIZE * @padding)

        @out.write(str, *args)
        super(str, *args)
      end
    end
  end
end
