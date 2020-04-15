# frozen_string_literal: true

module PhabricatorUpdater
  # module provides few helping methods with objects from GitLab
  module GitLabHelper
    def all_parent_group_slugs(namespace_attrs)
      slugs = []

      loop do
        slugs << Api::Conduit::Utils.make_slug(
          namespace_attrs.name
        )
        return slugs unless namespace_attrs.parent_id

        namespace_attrs = Gitlab.group(namespace_attrs.parent_id)
      end
    end

    def personal_project?
      is_personal = @gitlab_attrs.namespace.kind == 'user'
      if is_personal
        Api::Conduit::Logger.debug(
          message: 'Project was skipped.',
          project: { id: @gitlab_attrs.id }
        )
      end
      is_personal
    end

    def namespace_hash
      Digest::SHA2.hexdigest(@gitlab_attrs.path_with_namespace)[0..7]
    end

    def ignored_project?
      return false if @gitlab_attrs.respond_to?(:projects) # group

      p_s = PhabricatorUpdater::Config.gitlab.projects[@gitlab_attrs.id.to_s]
      return false unless p_s

      event_name = @gitlab_event['event_name'] || @gitlab_event['event_type']
      return false if p_s.fetch(:allow, []).include?(event_name)

      Api::Conduit::Logger.debug(
        message: 'Project was skipped.',
        project: { id: @gitlab_attrs.id }
      )

      true
    end

    def skip_project?
      personal_project? || ignored_project?
    end
  end
end
