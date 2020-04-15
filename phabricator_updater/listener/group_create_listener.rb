# frozen_string_literal: true

require_relative 'listener'

module PhabricatorUpdater
  # class which create Project in Phabricator and set slugs
  class GroupCreateListener < Listener
    def consume(event)
      group_attrs = Gitlab.group(event['group_id'])
      GroupUpdater.new(event, group_attrs).update
    end
  end
end
