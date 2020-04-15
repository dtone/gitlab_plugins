# frozen_string_literal: true

module PhabricatorUpdater
  # class shared
  # rubocop:disable Metrics/ClassLength
  class DiffusionRepositoryUpdater
    include PhabricatorUpdater::GitLabHelper
    include PhabricatorHelper
    include ::DT1::GitLabFileStorage

    DEFAULT_DIFFUSION_REPOSITORY_OPTIONS = {
      defaultBranch: :master,
      importOnly: false,
      permanentRefs: %w[master],
      publish: true,
      status: :active,
      vcs: :git
    }.freeze

    SET_ALWAYS_DIFFUSION_REPOSITORY_OPTIONS = {
      edit: :users,
      'policy.push': :users,
      view: :users
    }.freeze

    DEFAULT_URIS_OPTIONS = {
      io: :observe,
      display: :never,
      disable: false
    }.freeze

    def initialize(event, gitlab_attrs)
      @gitlab_event = event
      @gitlab_attrs = gitlab_attrs
    end

    def prepare_names_and_slugs
      phab_name_override = project_name_override(@gitlab_attrs.id)
      @name = (phab_name_override || @gitlab_attrs.name).capitalize
      @project_slug = Api::Conduit::Utils.make_slug(@name)
      @group_slugs = all_parent_group_slugs(@gitlab_attrs.namespace)
    end

    def update
      return if skip_project?
      return unless @gitlab_event['project_id'] # group

      prepare_names_and_slugs
      project = project_by_phid_in_gitlab!(@gitlab_attrs.id)
      repository = create_or_update_repository(project)

      {
        pretext: "Repository \"#{@name}\" has been \
#{@created_at ? 'created' : 'updated'}.",
        type: :info,
        urls: [
          link_to_repository(repository)
        ],
        user: { email: Gitlab.user(@gitlab_attrs.creator_id).email }
      }
    end

    def link_to_repository(repository)
      [
        'Link to repository in Phabricator',
        Api::Conduit::Utils.phabricator_link(
          "/diffusion/#{repository['id']}"
        )
      ]
    end

    def create_or_update_repository(project_attrs)
      repositories = search_repository_by_project(project_attrs)
      phids = project_attrs ? [project_attrs['phid']] : []

      group_projects = Api::Conduit.project_search(
        constraints: { slugs: @group_slugs }
      )
      phids << group_projects.first['phid'] if group_projects.first

      attrs = conduit_repository_attributes(phids)

      if repositories.empty?
        @created_at = Time.now
      else
        @updated_at = Time.now
        attrs[:objectIdentifier] = repositories.first['phid']
      end

      repository = ::Api::Conduit.diffusion_repository_edit(attrs)

      edit_gitlab_urls(repository)

      repository
    end

    def conduit_repository_attributes(phids)
      slugs_to_desc = @group_slugs.map { |s| s.prepend('#') }
      attrs = DEFAULT_DIFFUSION_REPOSITORY_OPTIONS.merge(
        # TODO
        # callsign: ,
        description: "#{slugs_to_desc.join(' ')} ##{@project_slug}",
        name: @name,
        space: ::Api::Conduit.space_phid,
        'projects.set': phids,
        status: @gitlab_attrs.archived ? :inactive : :active
      ).merge(SET_ALWAYS_DIFFUSION_REPOSITORY_OPTIONS)
      overrides = PhabricatorUpdater::Config.gitlab
                                            .projects[@gitlab_attrs.id.to_s]
      if overrides
        attrs.merge!(
          (overrides[:repository] || {}).slice(:view, :edit)
        )
      elsif @gitlab_attrs.namespace.kind == 'private'
        attrs[:view] = :administrator
        attrs[:edit] = :administrator
      end

      ::Api::Conduit::BodyFormatter.transactions(attrs.to_a)
    end

    def ssh_url(papth)
      "git@#{PhabricatorUpdater::Config.gitlab.ssh_domain}:#{papth}.git"
    end

    def edit_gitlab_urls(repository)
      repository_data = ::Api::Conduit.diffusion_repository_search(
        constraints: { phids: [repository['phid']] },
        attachments: { uris: true }
      )

      # set urls to GitLab
      url_opt = DEFAULT_URIS_OPTIONS.merge(
        repository: repository['phid'],
        uri: ssh_url(@gitlab_attrs.path_with_namespace),
        credential: DT1::Config.conduit.ssh_phid
      )

      url_opt = ::Api::Conduit::BodyFormatter.transactions(url_opt.to_a)
      disable_write_uris(repository_data)
      attachments_uris = repository_data.first
                                        .dig('attachments', 'uris', 'uris')

      uri = attachments_uris.find do |uri_attrs|
        uri_attrs.dig('fields', 'uri', 'raw')
                 .to_s["git@#{PhabricatorUpdater::Config.gitlab.ssh_domain}:"]
      end
      url_opt[:objectIdentifier] = uri['phid'] if uri

      ::Api::Conduit.diffusion_uri_edit(url_opt)
    end

    def disable_write_uris(rep_data)
      rep_data.first['attachments']['uris']['uris'].each do |uri_to_disable|
        next unless uri_to_disable.dig('fields', 'io', 'effective')
                                  .to_s['write']

        url_to_disable = ::Api::Conduit::BodyFormatter.transactions(io: :none)
        if uri_to_disable
          url_to_disable[:objectIdentifier] = uri_to_disable['phid']
        end
        ::Api::Conduit.diffusion_uri_edit(url_to_disable)
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
