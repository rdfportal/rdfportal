# frozen_string_literal: true

require 'tty-command'

module RDFPortal
  module Store
    module Util
      module ExternalCommand
        # @return [TTY::Command::Result]
        def external_command(*cmd, **options, &)
          options = { stdout: true, stderr: true, log: true }.merge(options)

          Base.logger.debug(PROGRAM_NAME) { "exec: #{cmd.join(' ')}" } if options[:log]

          tty = TTY::Command.new(printer: :null)
          tty.run(cmd.join(' '), env: options[:env] || {}) do |out, err|
            yield out.chomp if options[:stdout] && out.present?
            yield err.chomp if options[:stderr] && err.present?
          end
        end
      end
    end
  end
end
