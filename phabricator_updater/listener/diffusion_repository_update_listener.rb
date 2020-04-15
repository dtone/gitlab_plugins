# frozen_string_literal: true

require_relative 'listener'

module PhabricatorUpdater
  # class which updates diffusion repository in Phabricator
  class DiffusionRepositoryUpdateListener < Listener
    def consume(event)
      gitlab_attrs = Gitlab.project(event['project_id'])
      DiffusionRepositoryUpdater.new(event, gitlab_attrs).update
    end
  end
end
