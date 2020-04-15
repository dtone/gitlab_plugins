# frozen_string_literal: true

require 'base64'
require 'gitlab'
require 'oj'

require_relative 'error/project_not_found_error'

module DT1
  # module helps to load and update a file with Phabricator attributes
  module GitLabFileStorage
    UPDATE_BRANCH_NAME = :update_gitlab_plugins_file
    GITLAB_PLUGINS_FILE_NAME = '.gitlab_plugins'

    def gitlab_plugins_attrs(project_id)
      @gitlab_plugins_attrs = gitlab_plugins_attrs!(project_id)
    rescue StandardError => e
      # TODO
      DT1::Logger.warn(message: 'Project does not have file with phab attrs',
                       exception: e)
      @gitlab_plugins_attrs = {}
    end

    def gitlab_plugins_attrs!(project_id)
      return @gitlab_plugins_attrs if @gitlab_plugins_attrs

      Oj.load(fetch_file_content_from_gitlab!(project_id))
    end

    def project_name_override(project_id)
      gitlab_plugins_attrs(project_id).fetch('phabricator', {})
                                      .fetch('project', {})
                                      .fetch('name', nil)
    end

    def project_by_phid_in_gitlab!(project_id)
      plugin_content = gitlab_plugins_attrs!(project_id)
      gitlab_id = plugin_content.dig('gitlab', 'project', 'id')
      @update_file = gitlab_id.nil?
      if !gitlab_id.nil? && (gitlab_id.to_s != project_id.to_s)
        throw(:error,
              type: :warn,
              text: "Project GitLab ID #{project_id} is not equal value stored \
in #{GITLAB_PLUGINS_FILE_NAME} file (#{gitlab_id})")
      end
      project_phid = plugin_content.fetch('phabricator', {})
                                   .fetch('project', {})
                                   .fetch('phid', nil)
      if project_phid
        constraints = { phids: [project_phid] }
        project = Api::Conduit.project_search(constraints: constraints).first
        return project if project
      end

      # TODO
      # improve error to keep project_phid as a separate field
      raise(::ProjectNotFoundError,
            "Cannot find project by PHID #{project_phid} loaded in GitLab.")
    rescue Gitlab::Error::NotFound => e
      DT1::Logger.warn(message: 'Project does not have file with phab attrs',
                       exception: e)
      raise(ProjectNotFoundError, e.message)
    end

    def project_by_phid_in_gitlab(project_id)
      project_by_phid_in_gitlab!(project_id)
    rescue StandardError
      nil
    end

    def store_to_remote_file(project_id, file_content)
      return unless @update_file

      Gitlab.create_branch(project_id, UPDATE_BRANCH_NAME, :master)
      create_or_update_file(project_id, file_content)
      create_merge_request(project_id)
    end

    private

    def fetch_file_content_from_gitlab!(project_id)
      @update_file = false
      Base64.decode64(
        Gitlab.get_file(project_id, GITLAB_PLUGINS_FILE_NAME, :master).content
      )
    end

    def fetch_file_content_from_gitlab(project_id)
      fetch_file_content_from_gitlab!(project_id)
    rescue Gitlab::Error::NotFound => e
      DT1::Logger.warn(message: 'Project does not have file with phab attrs',
                       exception: e)

      '{}' # return empty JSON
    end

    def create_or_update_file(project_id, file_content)
      Gitlab.create_file(project_id,
                         GITLAB_PLUGINS_FILE_NAME, UPDATE_BRANCH_NAME,
                         file_content.to_json,
                         "GP: Updated file \
which maps GitLab projects to Phabricator projects")
    rescue Gitlab::Error::BadRequest => e
      raise e unless e.message[/A file with this name already exists/]

      original = fetch_file_content_from_gitlab(project_id)
      Gitlab.edit_file(project_id, GITLAB_PLUGINS_FILE_NAME, UPDATE_BRANCH_NAME,
                       Oj.load(original, symbolize_names: true)
                                      .merge(file_content).to_json,
                       "GP: Update file: #{GITLAB_PLUGINS_FILE_NAME} \
with project mapping in GitLab and Phabricator")
    end

    def create_merge_request(project_id)
      mr_attrs = Gitlab.create_merge_request(project_id,
                                             'Update gitlab_plugins file',
                                             source_branch: UPDATE_BRANCH_NAME,
                                             target_branch: :master)

      Gitlab.accept_merge_request(project_id, mr_attrs.iid,
                                  merge_commit_message: 'auto accept',
                                  should_remove_source_branch: true)
    end
  end
end
