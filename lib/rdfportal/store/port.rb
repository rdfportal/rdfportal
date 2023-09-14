# frozen_string_literal: true

require 'socket'

module RDFPortal
  module Store
    class Port
      class << self
        # @param [String] port
        # @param [String] host
        # @return [FalseClass, TrueClass]
        def listen?(port, host = 'localhost')
          ::TCPSocket.open(host, port).close
          true
        rescue Errno::ECONNREFUSED
          false
        end
      end
    end
  end
end
