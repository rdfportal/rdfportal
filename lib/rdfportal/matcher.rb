# frozen_string_literal: true

module RDFPortal
  class Matcher < Regexp
    REGEXP = %r{\A/(.*)/(\w+)?\z}

    def initialize(pattern)
      options = 0

      if pattern.is_a?(Regexp)
        options = pattern.options
      elsif (m = pattern.match(REGEXP))
        pattern = m[1]
        options = Regexp::IGNORECASE if m[2]&.include?('i')
      else
        pattern = "^#{Regexp.escape(pattern).gsub('\*', '[^/]*').gsub('\?', '[^/]')}$"
      end

      super(pattern, options)
    end
  end
end
