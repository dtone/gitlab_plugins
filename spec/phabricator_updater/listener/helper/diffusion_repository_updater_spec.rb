# frozen_string_literal: true

# it also allows testing requires in phabricator updater
# do not require files in specs
require_relative '../../../support/phabricator_updater_spec_helper'

RSpec.describe PhabricatorUpdater::DiffusionRepositoryUpdater do
  subject(:updater) do
    described_class.new(event, gitlab_project)
  end

  let(:event) do
    {
      'project_id' => project_id,
      'name' => 'RSpec Project',
      'description' => 'short desc'
    }
  end
  let(:slug) { 'rspec_project' }
  let(:attrs) do
    { 'phabricator' => { 'project' => { 'phid' => project_phid } } }
  end
  let(:content) { attrs.to_json }
  let(:base64_content) do
    Base64.encode64(content)
  end
  let(:gitlab_file) do
    Gitlab::ObjectifiedHash.new(
      content: base64_content,
      kind: 'public'
    )
  end
  let(:project_id) { 42 }
  let(:project_phid) { 'PHIDb0rd3L' }
  let(:gitlab_project) do
    Gitlab::ObjectifiedHash.new(
      namespace: gitlab_group,
      name: event['name'],
      id: project_id,
      archived: false,
      path_with_namespace: 'group_name/rspec_project'
    )
  end
  let(:group_name) { 'Group Name' }
  let(:group_phid) { 'PHIDPiCe' }
  let(:group_slug) { 'group_name' }
  let(:group_attrs) { { 'phid' => group_phid } }
  let(:gitlab_group)  do
    Gitlab::ObjectifiedHash.new(
      name: group_name,
      parent_id: nil,
      kind: 'user'
    )
  end

  let(:response_404) do
    instance_double(
      HTTParty::Response, parsed_response: '', code: 404,
                          request: instance_double(HTTParty::Request,
                                                   base_uri: '',
                                                   path: '')
    )
  end

  # it loads overrides for project everytime
  before do
    allow(Gitlab).to receive(:get_file)
      .and_raise(
        Gitlab::Error::NotFound.new(response_404)
      )
  end

  describe '#project_by_phid_in_gitlab' do
    it 'search project by GitLab file' do
      aggregate_failures do
        expect(Gitlab).to receive(:get_file)
          .with(project_id, '.gitlab_plugins', :master)
          .and_return(gitlab_file)
        expect(Api::Conduit).to receive(:project_search)
          .with(constraints: { phids: [project_phid] }).and_return([])
      end
      updater.project_by_phid_in_gitlab(project_id)
    end

    it 'does not search - because file not found' do
      aggregate_failures do
        expect(Gitlab).to receive(:get_file)
          .and_raise(
            Gitlab::Error::NotFound.new(response_404)
          )

        expect(Api::Conduit).not_to receive(:project_search)
      end
      updater.project_by_phid_in_gitlab(project_id)
    end
  end

  describe '#create_or_update_repository' do
    let(:repository_phid) { 'PHIDRDk2ee9m' }
    let(:project_attrs) { { 'phid' => project_phid } }
    let(:url_phid) { 'PHIDn3SmYs1' }
    let(:repository_attrs) do
      {
        'phid' => repository_phid,
        'attachments' =>
        { 'uris' => { 'uris' => [{ 'phid' => url_phid }] } }
      }
    end

    let(:expected_attrs) do
      [
        %i[defaultBranch master],
        [:importOnly, false],
        [:permanentRefs, %w[master]],
        [:publish, true],
        %i[status active],
        %i[vcs git],
        [:description, "##{group_slug} ##{slug}"],
        [:name, event['name'].capitalize],
        [:space, ::Api::Conduit.space_phid],
        [:'projects.set', [project_phid, group_phid]],
        %i[edit users],
        %i[policy.push users],
        %i[view users]
      ]
    end

    before do
      allow(Gitlab).to receive(:project).and_return(gitlab_project)
      allow(Api::Conduit).to receive(:project_search).with(
        constraints: { slugs: ['group_name'] }
      ).and_return([group_attrs])
      updater.prepare_names_and_slugs
    end

    it 'creates repository' do
      allow(updater).to receive(:edit_gitlab_urls)
      aggregate_failures do
        expect(::Api::Conduit::BodyFormatter).to receive(:transactions)
          .with(expected_attrs)
        expect(::Api::Conduit).to receive(:diffusion_repository_search)
          .and_return([])
        expect(::Api::Conduit).to receive(:diffusion_repository_edit)
          .and_return(project_attrs)
      end
      updater.create_or_update_repository(project_attrs)
    end

    it 'updates repository' do
      allow(updater).to receive(:edit_gitlab_urls)
      aggregate_failures do
        expect(::Api::Conduit).to receive(:diffusion_repository_search)
          .and_return([repository_attrs])
        expect(::Api::Conduit).to receive(:diffusion_repository_edit)
          .with(hash_including(objectIdentifier: repository_phid))
      end
      updater.create_or_update_repository(project_attrs)
    end

    it 'sets gitlab urls' do
      allow(::Api::Conduit).to receive(:diffusion_repository_edit)
        .and_return('phid' => repository_phid)
      allow(::Api::Conduit).to receive(:diffusion_repository_search)
        .and_return([repository_attrs])
      expect(::Api::Conduit).to receive(:diffusion_uri_edit)
      updater.create_or_update_repository(project_attrs)
    end
  end

  describe '#conduit_repository_attributes' do
    before do
      allow(Gitlab).to receive(:project).and_return(gitlab_project)
      allow(Api::Conduit).to receive(:project_search).with(
        constraints: { slugs: ['group_name'] }
      ).and_return([group_attrs])
      updater.prepare_names_and_slugs
    end

    let(:gitlab_config) do
      instance_double('gitlab_config',
                      projects: { gitlab_project.id.to_s => {
                        repository: {
                          view: :my_group,
                          edit: :admin_group
                        }
                      } })
    end

    let(:expected_attrs) do
      [
        %i[defaultBranch master],
        [:importOnly, false],
        [:permanentRefs, %w[master]],
        [:publish, true],
        %i[status active],
        %i[vcs git],
        [:description, "##{group_slug} ##{slug}"],
        [:name, gitlab_project.name.capitalize],
        [:space, ''],
        [:'projects.set', []],
        %i[edit admin_group],
        %i[policy.push users],
        %i[view my_group]
      ]
    end

    it 'overrides policy', :aggregate_failures do
      expect(PhabricatorUpdater::Config).to receive(:gitlab)
        .and_return(gitlab_config)
      expect(::Api::Conduit::BodyFormatter).to receive(:transactions)
        .with(expected_attrs)
      updater.conduit_repository_attributes([])
    end
  end
end
