# frozen_string_literal: true

require 'pycall'
require 'open3'

module RDFPortal
  class Python

    class InstallError < StandardError; end

    class << self
      include ExternalCommand

      def executable
        python[:executable]
      end

      def installed?(lib)
        importlib_util.find_spec(lib) != nil
      end

      def install(lib)
        RDFPortal.logger.info(self.class) { "Installing #{lib}..." }

        cmd = [
          executable,
          '-m',
          'pip',
          'install',
          lib
        ]

        run_cmd!(*cmd, stdout: :info, stderr: :info)
      end

      private

      def python
        @python ||= PyCall::LibPython::Finder.find_python_config(ENV.fetch('PYTHON', nil)).last
      end

      def importlib_util
        @importlib_util ||= PyCall.import_module('importlib.util')
      end
    end
  end
end
