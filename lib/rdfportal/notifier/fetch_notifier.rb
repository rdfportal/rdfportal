# frozen_string_literal: true

module RDFPortal
  class Notifier
    class FetchNotifier < Notifier
      # @param [RDFPortal::Interaction::Results] result
      def initialize(result, started_at:, finished_at:, remaining_job_count:, log_file:)
        super()
        @result = result
        @started_at = started_at
        @finished_at = finished_at
        @remaining_job_count = Integer(remaining_job_count, exception: false)
        @log_file = log_file.to_s
      end

      def deliver
        return if @result.values.all? { |v| v.any?(&:skipped?) }

        super
      end

      private

      # rubocop:disable Rubycw/Rubycw
      def bindings
        preview_icon, color, status = if @result.success?
                                        [ICON_SUCCESS, COLOR_SUCCESS, 'Success']
                                      elsif @result.failure?
                                        [ICON_FAILURE, COLOR_FAILURE, 'Failure']
                                      else
                                        [ICON_WARNING, COLOR_WARNING, 'Check required']
                                      end
        name = File.basename(@result.directory_prefix)
        directory = @result.directory_prefix
        disk_usage = `du -sh #{@result.directory_prefix} | cut -f1`.strip
        time = (@finished_at - @started_at).readable_duration
        context = build_context

        binding
      end
      # rubocop:enable Rubycw/Rubycw

      def template_dir
        File.expand_path(File.join('template', 'fetch'), __dir__)
      end

      def render_slack_body
        ERB.new(File.read(File.join(template_dir, 'slack.json.erb')), trim_mode: '-').result(bindings)
      end

      def render_mail
        raise NotImplementedError
      end

      def build_context
        context = [
          "*Started at:* #{strftime(@started_at) || 'N/A'}",
          "*Finished at:* #{strftime(@finished_at) || 'N/A'}"
        ]

        if @result.present? && !@result.success?
          context << '```'

          @result.each_key do |k|
            icon = if @result.skipped?(k)
                     ICON_SKIPPED
                   elsif @result.success?(k)
                     ICON_SUCCESS
                   elsif @result.failure?(k)
                     ICON_FAILURE
                   else
                     ICON_WARNING
                   end

            context << "#{icon} #{k}"

            next if @result.skipped?(k) || @result.success?(k)

            Array(@result[k]).each do |result|
              context << "   #{result.success? ? ICON_SUCCESS : ICON_FAILURE} #{result.message}"
            end
          end

          context << '```'

          context << "Log file `#{@log_file}`"
        end

        context << "*Remaining jobs:* #{@remaining_job_count}" if @remaining_job_count&.positive?

        context.join("\n")
      end
    end
  end
end
