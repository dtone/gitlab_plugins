# frozen_string_literal: true

module PhabricatorUpdater
  # parent class with basic functionality
  class Listener
    class << self
      def notify(event)
        new.consume(event)
      rescue StandardError => e
        throw(:error,
              type: :error,
              event: event.to_json,
              pretext: 'Could you look at who breaks eggs?!',
              title: e.message,
              text: e.backtrace.join("\n\t"))
      end
    end
  end
end
