# frozen_string_literal: true

class SlackNotifier
  # formatter for Slack message
  class MessageFormatter
    class << self
      MESSAGE_DEFAULT = {
        as_user: false,
        link_names: true,
        parse: :full
      }.freeze

      def format(report, attachments)
        MESSAGE_DEFAULT.merge(
          text: report.fetch(:event, nil),
          attachments: attachments
        )
      end
    end
  end
end
