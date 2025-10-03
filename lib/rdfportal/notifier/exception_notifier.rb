# frozen_string_literal: true

module RDFPortal
  class Notifier
    class ExceptionNotifier < Notifier
      # @param [Exception] exception
      def initialize(exception, title: nil, log_file: nil)
        super()
        @exception = exception
        @title = title
        @log_file = log_file
      end

      private

      # rubocop:disable Rubycw/Rubycw
      def bindings
        preview_icon = ICON_FAILURE
        color = COLOR_FAILURE
        message = @exception.message

        title = @title
        log_file = @log_file

        binding
      end
      # rubocop:enable Rubycw/Rubycw

      def template_dir
        File.expand_path(File.join('template', 'exception'), __dir__)
      end

      def render_slack_body
        ERB.new(File.read(File.join(template_dir, 'slack.json.erb')), trim_mode: '-').result(bindings)
      end

      def render_mail
        raise NotImplementedError
      end
    end
  end
end
