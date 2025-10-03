# frozen_string_literal: true

module RDFPortal
  class Notifier
    include ActionView::Helpers::JavaScriptHelper

    COLOR_SUCCESS = '#198754'
    COLOR_WARNING = '#ffc107'
    COLOR_FAILURE = '#dc3545'

    ICON_SUCCESS = '✅'
    ICON_WARNING = '⚠️'
    ICON_FAILURE = '❌'
    ICON_SKIPPED = '⏩'

    def deliver
      # TODO: implement mail notification
      return unless (webhook = RDFPortal.slack_webhook_url)

      notifier = Slack::Notifier.new(webhook)

      body = JSON.parse(render_slack_body)

      notifier.post(body)
    end

    private

    def strftime(time)
      return unless time.present?

      time.strftime('%Y/%m/%d %H:%M:%S %Z')
    end

    # @return [String] post body
    def render_slack_body
      raise NotImplementedError
    end

    def render_mail
      raise NotImplementedError
    end
  end

  require 'rdfportal/notifier/exception_notifier'
  require 'rdfportal/notifier/fetch_notifier'
end
