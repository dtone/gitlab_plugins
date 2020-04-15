# frozen_string_literal: true

class SlackNotifier
  # format urls to Slack
  # nothing big - pure convert to buttons
  class UrlFormatter
    class << self
      def format(urls)
        return [] unless urls

        urls.map { |url| action_link(*url) }
      end

      # maybe allow some configuration
      def action_link(text, link)
        {
          type: :button,
          text: text,
          url: link,
          short: true
        }
      end
    end
  end
end
