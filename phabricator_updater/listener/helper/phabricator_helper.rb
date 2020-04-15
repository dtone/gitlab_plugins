# frozen_string_literal: true

module PhabricatorUpdater
  # module provides few helping methods with objects from Phabricator
  module PhabricatorHelper
    PHAB_ERR_SAME_SLUG =
      /Project name generates the same hashtag \(\\+\"(?<slug>.*)\\+\"\)/.freeze

    def search_repository_by_project(project)
      return [] unless project

      ::Api::Conduit.diffusion_repository_search(
        constraints: { projects: [project['phid']] },
        attachments: { projects: true }
      )
    end

    def search_repository_by_project!(project)
      repositories = search_repository_by_project(project)
      return repositories unless repositories.empty?

      throw(:error,
            text: "Cannot find repository by project #{project}.")
    end

    def update_attributes(project)
      Api::Conduit::BodyFormatter.transactions(
        subtype: :sourcecode,
        description: @gitlab_attrs.description.to_s,
        name: @name,
        slugs: [@project_slug]
      ).merge(objectIdentifier: project['phid'])
    end

    def create_attributes
      Api::Conduit::BodyFormatter.transactions(
        subtype: :sourcecode,
        description: @gitlab_attrs.description.to_s,
        name: @name,
        slugs: [@project_slug],
        space: ::Api::Conduit.space_phid
      )
    end

    def project_by_gitlab_url(url)
      Api::Conduit.project_search(
        constraints:
        { 'custom.gitlab.url': [url] }
      ).first
    end

    def search_same_slug(slug)
      Api::Conduit.project_search(
        constraints:
        { slugs: [slug] }
      )
    end

    def guard_same_slug(slug)
      return nil if search_same_slug(slug).empty?

      throw_same_slug(slug)
    end

    def throw_same_slug(slug)
      throw(:error,
            type: :warn,
            text:
            format(
              'Projects with slug %<slug>s already exists in Phabricator.\
    Rename project/group or add overrides to details see README.',
              slug: slug
            ))
    end

    def edit_project_rescue_same_slug(attrs)
      Api::Conduit.project_edit(attrs)
    rescue StandardError => e
      match = e.message.match(PHAB_ERR_SAME_SLUG)
      throw_same_slug(match[:slug]) if match[:slug]
      raise
    end

    def create_or_update_project
      project = phabricator_project

      attrs = if project
                @updated_at = Time.now
                update_attributes(project)
              else
                @created_at = Time.now
                create_attributes
              end

      # TODO
      # check what is really updated in GitLab
      project = edit_project_rescue_same_slug(attrs)
      # set slugs again to clear previous
      if @updated_at
        Api::Conduit.project_edit(
          Api::Conduit::BodyFormatter.transactions(slugs: [@project_slug])
          .merge(objectIdentifier: project['phid'])
        )
      end
      update_custom_fields(project)
    end

    def update_custom_fields(project)
      Api::Conduit.project_edit(
        Api::Conduit::BodyFormatter.transactions(
          'custom.gitlab.url': @gitlab_attrs.web_url
        ).merge(objectIdentifier: project['phid'])
      )
    end

    def default_urls(name, slug, gitlab_path_with_namespace)
      [
        ["Link to #{name} in Phabricator",
         Api::Conduit::Utils.phabricator_link("tag/#{slug}")],
        ["Link to #{name} in GitLab",
         Api::Conduit::Utils.gitlab_link(gitlab_path_with_namespace)]
      ]
    end
  end
end
