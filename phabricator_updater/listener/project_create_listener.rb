# frozen_string_literal: true

require_relative 'listener'

module PhabricatorUpdater
  # class which create Project in Phabricator and set slugs
  class ProjectCreateListener < Listener
    def consume(event)
      project_attrs = Gitlab.project(event['project_id'])
      ProjectUpdater.new(event, project_attrs).update
    end
  end
end
