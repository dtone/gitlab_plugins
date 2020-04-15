# frozen_string_literal: true

require_relative 'listener'

module PhabricatorUpdater
  # class which creates diffusion repository in Phabricator
  class DiffusionRepositoryCreateListener < Listener
    def consume(event)
      gitlab_attrs = Gitlab.project(event['project_id'])
      DiffusionRepositoryUpdater.new(event, gitlab_attrs).update
    end
  end
end
