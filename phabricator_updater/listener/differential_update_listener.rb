# frozen_string_literal: true

require_relative 'listener'

module PhabricatorUpdater
  # parent class with basic functionality
  class DifferentialUpdateListener < Listener
    def consume(event)
      gitlab_mr = Gitlab.merge_request(
        event['object_attributes']['target_project_id'],
        event['object_attributes']['iid']
      )
      DifferentialUpdater.new(event, gitlab_mr).update
    end
  end
end
