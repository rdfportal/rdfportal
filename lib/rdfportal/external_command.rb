# frozen_string_literal: true

require 'tty-command'
require 'rdfportal/extension'

module RDFPortal
  module ExternalCommand

    # @return [TTY::Command::Result]
    def run_cmd(*cmd, **options)
      %i[command_log stdout stderr].each do |x|
        next if options[x] == false

        options[x] ||= :debug
      end

      unless options[:command_log] == false
        RDFPortal.logger.send(options[:command_log], self.class) { cmd_string(*cmd, **cmd_options(**options)) }
      end

      time, ret = Benchmark.realtime_with_return do
        method = options[:exception] ? :run : :run!

        TTY::Command.new(printer: :null).send(method, *cmd, **cmd_options(**options)) do |out, err|
          if (out = out&.strip).present? && options[:stdout] != false
            out = options[:format].call(out) if options[:format]

            if options[:stdout].respond_to?(:write)
              options[:stdout].write(out, "\n")
            elsif RDFPortal.logger.respond_to?(options[:stdout])
              RDFPortal.logger.send(options[:stdout], self.class) { "[STDOUT] #{out}" }
            end
          end

          if (err = err&.strip).present? && options[:stderr] != false
            err = options[:format].call(err) if options[:format]

            if options[:stderr].respond_to?(:write)
              options[:stderr].write(err, "\n")
            elsif RDFPortal.logger.respond_to?(options[:stderr])
              RDFPortal.logger.send(options[:stderr], self.class) { "[STDERR] #{err}" }
            end
          end
        end
      end

      # set command string for exception handling
      ret.command = cmd_string(*cmd, **options) if ret.respond_to?(:command=)

      RDFPortal.logger.debug(self.class) do
        "Finished in #{time.readable_duration} with exit status #{ret.status}."
      end

      ret
    end

    def run_cmd!(*cmd, **options)
      run_cmd(*cmd, **options, exception: true)
    end

    def cmd_options(**options)
      options.slice(:chdir, :dry_run, :env, :in).compact
    end

    def cmd_string(*cmd, **options)
      TTY::Command::Cmd.new(*cmd, **cmd_options(**options)).to_command
    end

    # @param [TTY::Command::Result] result
    def extract_details(result)
      msg = []
      msg << "command: #{result.command}" if result.respond_to?(:command)
      msg << "exit code: #{result.exit_status}" unless result.exit_status.zero?
      msg << "stdout: #{extract_output(result.out)}"
      msg << "stderr: #{extract_output(result.err)}"

      msg.join("\n")
    end

    def extract_output(value)
      (value || '').strip.empty? ? 'Nothing written' : value.strip
    end
  end
end
