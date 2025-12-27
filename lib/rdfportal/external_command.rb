# frozen_string_literal: true

require 'tty-command'
require 'rdfportal/extension'

module RDFPortal
  module ExternalCommand
    # @return [TTY::Command::Result]
    def run_cmd(*cmd, **options)
      runner = TTY::Command.new(printer: RDFPortal::ExternalCommand::LogPrinter)
      runner.printer.stdout = options[:stdout]
      runner.printer.stderr = options[:stderr]
      runner.printer.formatter = options[:formatter]
      runner.printer.logger = options[:logger] || RDFPortal.logger
      runner.printer.command_log = options[:command_log]
      runner.printer.caller = is_a?(Class) ? self : self.class

      method = options[:exception] ? :run : :run!

      options[:only_output_on_error] ||= true

      ret = runner.send(method, *cmd, **cmd_options(**options))

      # set command string for exception handling
      ret.command = cmd_string(*cmd, **options) if ret.respond_to?(:command=)

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

    class LogPrinter < TTY::Command::Printers::Abstract
      TIME_FORMAT = '%5.3f %s'

      attr_accessor :command_log, :stdout, :stderr, :formatter, :logger, :caller

      def print_command_start(cmd, *args)
        return if @command_log == false

        message = ["Running #{cmd.to_command}"]
        message << args.map(&:chomp).join(' ') unless args.empty?

        write(cmd, message.join)
      end

      def print_command_out_data(cmd, *args)
        message = args.map { |x| x.sub(/\A[\r\n]+/, '').chomp }.join(' ')
        write(cmd, message, out_data, :out)
      end

      def print_command_err_data(cmd, *args)
        message = args.map { |x| x.sub(/\A[\r\n]+/, '').chomp }.join(' ')
        write(cmd, message, err_data, :err)
      end

      def print_command_exit(cmd, status, runtime, *args)
        if cmd.only_output_on_error && !status.zero?
          output << out_data
          output << err_data
        end

        return if @command_log == false

        runtime = format(TIME_FORMAT, runtime, 'second'.pluralize(runtime))
        message = ["Finished in #{runtime}"]
        message << " with exit status #{status}" if status
        message << " (#{status.zero? ? 'success' : 'failure'})"

        write(cmd, message.join)
      end

      def write(cmd, message, data = nil, stream = nil)
        if @logger
          method, name = if stream == :out
                           [@stdout.is_a?(Symbol) && @logger.respond_to?(@stdout) ? @stdout : :debug, 'STDOUT']
                         elsif stream == :err
                           [@stderr.is_a?(Symbol) && @logger.respond_to?(@stderr) ? @stderr : :debug, 'STDERR']
                         else
                           [:info, @caller || self.class]
                         end

          message.each_line { |line| @logger.send(method, name) { line.chomp } }
        end

        message = @formatter.call(message) if @formatter

        if cmd.only_output_on_error && !data.nil?
          data << "#{message}\n"
        elsif stream == :out
          if @stdout.nil? && @stdout != false
            output << "#{message}\n"
          elsif @stdout.respond_to?(:write)
            @stdout.write(message, "\n")
          end
        elsif stream == :err
          if @stderr.nil?
            output << "#{message}\n"
          elsif @stderr.respond_to?(:write)
            @stderr.write(message, "\n")
          end
        end
      end
    end
  end
end
