# frozen_string_literal: true

require_relative '../../lib/conduit/conduit'
require_relative '../../lib/conduit/utils'

module PhabricatorUpdater
  # class shared
  class ProjectUpdater
    include ::DT1::GitLabFileStorage
    include PhabricatorUpdater::GitLabHelper
    include PhabricatorHelper

    def initialize(event, gitlab_attrs)
      @gitlab_event = event
      @gitlab_attrs = gitlab_attrs
      prepare_names_and_slugs
    end

    def phabricator_project
      project_by_phid_in_gitlab!(@gitlab_attrs.id)
    rescue ProjectNotFoundError => e
      DT1::Logger.warn(message: 'Project does not have file with phab attrs',
                       exception: e)
      project = project_by_gitlab_url(@gitlab_attrs.web_url)
      return project if project

      # add "random postfix to name override"
      # and reload name and slugs
      unless search_same_slug(@project_slug).empty?
        prepare_names_and_slugs(create_name_override)
      end
      @update_file = true # store created project after create
      nil # project was not found, return nil
    end

    def create_name_override
      "#{@name} #{namespace_hash}"
    end

    def prepare_names_and_slugs(name_override = nil)
      @name = if name_override
                name_override.capitalize
              else
                phab_name_override = project_name_override(@gitlab_attrs.id)
                (phab_name_override || @gitlab_attrs.name).capitalize
              end

      @project_slug = Api::Conduit::Utils.make_slug(@name)
    end

    def update
      return if skip_project?

      prj_attrs = create_or_update_project

      file_content = {
        gitlab: { project: { id: @gitlab_attrs.id } },
        phabricator: {
          project: {
            id: prj_attrs['id'], phid: prj_attrs['phid']
          }
        }
      }
      if @name.capitalize != @gitlab_attrs.name.capitalize
        file_content[:phabricator][:project][:name] = @name
        @update_file = true
      end
      store_to_remote_file(@gitlab_attrs.id, file_content)

      path = @gitlab_attrs.path_with_namespace

      {
        pretext: "Project \"#{@name}\" with slug \"#{@project_slug}\" has been \
#{@created_at ? 'created' : 'updated'}.",
        type: :info,
        urls: default_urls(@name, @project_slug, path),
        user: { email: Gitlab.user(@gitlab_attrs.creator_id).email }
      }
    end
  end
end
