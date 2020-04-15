# frozen_string_literal: true

class SlackNotifier
  # format urls to Slack
  # nothing big - pure convert to buttons
  class AttachmentFormatter
    # easter egg with names

    INTERESTING_PERSONS = File.open(
      File.join(File.dirname(__FILE__), 'roles'), 'r:UTF-8'
    ) { |f| f.readlines.to_a }

    ATTACHMENT_DEFAULT = {
      footer: 'GitLab Plugins'
    }.freeze

    COLOR_TYPE_MAP = {
      info: :good,
      warn: :warning,
      error: :danger
    }.freeze

    class << self
      def attachment_default_with_person
        person = INTERESTING_PERSONS.sample
        ATTACHMENT_DEFAULT.merge(
          author_name: person,
          author_link: "https://www.google.com/search?q=\
#{Rack::Utils.escape(person)}"
        )
      end

      def format(report, actions, mention)
        gitlab_owner = report.dig(:user, :email).to_s.split('@').first

        mention_text = if gitlab_owner
                         ' for ' + (mention ? '@' : '') + gitlab_owner
                       else
                         '.'
                       end
        {
          actions: actions,
          color: color_by_type(report.fetch(:type, :info)),
          title: report.fetch(:title,
                              "thinks it could be usefull#{mention_text}"),
          pretext: report.fetch(:pretext, ''),
          text: report.fetch(:text, '')
        }.merge(attachment_default_with_person)
      end

      def color_by_type(type)
        COLOR_TYPE_MAP[type]
      end
    end
  end
end
