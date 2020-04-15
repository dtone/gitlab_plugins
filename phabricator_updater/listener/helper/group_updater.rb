# frozen_string_literal: true

require 'digest/sha2'

require_relative '../../lib/conduit/conduit'
require_relative '../../lib/conduit/utils'

module PhabricatorUpdater
  # class shared
  class GroupUpdater
    include PhabricatorHelper

    def initialize(event, gitlab_attrs)
      @gitlab_event = event
      @gitlab_attrs = gitlab_attrs
      prepare_names_and_slugs
    end

    # search project in Phabricator
    # at first only by custom field
    # when nothing found
    # try search by slug to avoid duplicates
    def phabricator_project
      project = project_by_gitlab_url(@gitlab_attrs.web_url)
      return project if project

      guard_same_slug(@project_slug)
    end

    def create_project_name_override(project_id)
      gitlab_plugins_attrs(project_id)['phabricator']['project']['name'] =
        "#{@name} #{namespace_hash}"
    end

    def prepare_names_and_slugs
      @name = @gitlab_attrs.name.capitalize
      @project_slug = Api::Conduit::Utils.make_slug(@name)
    end

    def update
      create_or_update_project

      {
        pretext: "Project \"#{@name}\" with slug \"#{@project_slug}\" has been \
#{@created_at ? 'created' : 'updated'}.",
        type: :info,
        urls: default_urls(@name, @project_slug, @gitlab_attrs.path)
      }
    end
  end
end
