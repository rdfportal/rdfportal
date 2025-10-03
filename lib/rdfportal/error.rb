# frozen_string_literal: true

module RDFPortal
  # Base error class for the module
  class Error < StandardError; end

  class ExternalCommandError < StandardError
    # @param [TTY::Command::Result] result
    def initialize(result)
      msg = ["External command failed with exit code #{result.exit_status}"]
      msg << "  command: #{result.command}" if result.respond_to?(:command)
      msg << "  stdout: #{extract_output(result.out)}"
      msg << "  stderr: #{extract_output(result.err)}"

      super(msg.join("\n"))
    end

    private

    def extract_output(value)
      (value || '').strip.empty? ? 'Nothing written' : value.strip
    end
  end

  class DirectoryNotFoundError < Error
    attr_reader :path

    def initialize(path)
      @path = path
      super("Directory not found: #{path}")
    end
  end

  class InvalidConfigurationError < Error
    attr_accessor :input, :path

    def message
      [super, "#{input}#{" in #{path}" if path}"].join("\n")
    end
  end

  class ParameterNotDefinedError < Error; end

  class HTTPRequestError < Error
    def initialize(response)
      @response = response
      super("#{response.response_code} #{response.status_message}")
    end

    def message
      "#{super}, url = #{@response.effective_url}, body = #{@response.body}"
    end
  end

  class Result
    PADDING_SIZE = 2

    module Status
      SUCCESS = :success
      FAILURE = :failure
      SKIPPED = :skipped
      ERROR = :error
    end

    attr_reader :details, :message, :status, :working_dir

    def initialize(status, message, details = nil)
      @status = status.is_a?(Symbol) ? status : Status.const_get(status.to_s.upcase)
      @message = message
      @details = details
    end

    def success?
      @status == Status::SUCCESS
    end

    def failure?
      @status == Status::FAILURE
    end

    def skipped?
      @status == Status::SKIPPED
    end

    def error?
      @status == Status::ERROR
    end

    def to_s
      status = "[#{@status.to_s.camelize}] "

      if @details
        "#{status}#{@message}\n#{@details.to_s.indent(PADDING_SIZE)}"
      else
        "#{status}#{@message}"
      end
    end
  end
end
