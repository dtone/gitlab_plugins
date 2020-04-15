# frozen_string_literal: true

# it also allows testing requires in phabricator updater
# do not require files in specs
require_relative '../../../support/phabricator_updater_spec_helper'

RSpec.describe PhabricatorUpdater::ProjectUpdater do
  subject(:updater) do
    described_class.new(event, gitlab_project)
  end

  let(:event) do
    {
      'project_id' => project_id,
      'name' => 'rspec project'
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
      content: base64_content
    )
  end
  let(:gitlab_group) do
    Gitlab::ObjectifiedHash.new(
      name: 'GitLab Group'
    )
  end
  let(:gitlab_project) do
    Gitlab::ObjectifiedHash.new(
      namespace: gitlab_group,
      path_with_namespace: '/group/project',
      web_url: 'http://git.fake.universe/group/project',
      name: event['name'],
      description: nil,
      id: project_id
    )
  end
  let(:project_id) { 42 }
  let(:project_phid) { 'PHIDb0rd3L' }
  let(:project_attrs) { { 'phid' => project_phid } }
  let(:response_404)  do
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

  describe '#phabricator_project' do
    it 'does not find project', :aggregate_failures do
      expect(Gitlab).to receive(:get_file)
        .and_raise(
          Gitlab::Error::NotFound.new(response_404)
        )
      expect(Api::Conduit).to receive(:project_search)
        .with(constraints: { 'custom.gitlab.url': [gitlab_project.web_url] })
        .and_return([])
      expect(Api::Conduit).to receive(:project_search)
        .with(constraints: { slugs: [slug] }).and_return([])
      expect(updater.phabricator_project).to be nil
    end

    it 'find project by GitLab file' do
      aggregate_failures do
        expect(Gitlab).to receive(:get_file)
          .with(project_id, '.gitlab_plugins', :master)
          .and_return(gitlab_file)
        expect(Api::Conduit).to receive(:project_search)
          .with(constraints: { phids: [project_phid] })
          .and_return([project_attrs])
      end
      updater.phabricator_project
    end

    it 'find project by name' do
      aggregate_failures do
        expect(Gitlab).to receive(:get_file)
          .and_raise(
            Gitlab::Error::NotFound.new(response_404)
          )
        expect(Api::Conduit).to receive(:project_search)
          .with(constraints: { 'custom.gitlab.url': [gitlab_project.web_url] })
          .and_return([])
        expect(Api::Conduit).to receive(:project_search)
          .with(constraints: { slugs: [slug] }).and_return([{}])
        updater.phabricator_project
      end
    end

    it 'override name' do
      aggregate_failures do
        expect(Gitlab).to receive(:get_file)
          .and_raise(
            Gitlab::Error::NotFound.new(response_404)
          )
        expect(Api::Conduit).to receive(:project_search)
          .with(constraints: { 'custom.gitlab.url': [gitlab_project.web_url] })
          .and_return([])
        expect(Api::Conduit).to receive(:project_search)
          .with(constraints: { slugs: [slug] }).and_return([{}])
        expect(updater).to receive(:prepare_names_and_slugs)
          .with('Rspec project 7b143123')
        updater.phabricator_project
      end
    end

    it 'find project by custom gitlab url' do
      aggregate_failures do
        expect(Gitlab).to receive(:get_file)
          .and_raise(
            Gitlab::Error::NotFound.new(response_404)
          )
        expect(Api::Conduit).to receive(:project_search)
          .with(constraints: { 'custom.gitlab.url': [gitlab_project.web_url] })
          .and_return([{}])
      end
      updater.phabricator_project
    end
  end

  describe '#update_custom_fields' do
    it 'updates link to GitLab' do
      expect(Api::Conduit).to receive(:project_edit)
        .with(transactions: { '0' => {
                type: :'custom.gitlab.url',
                value: gitlab_project.web_url
              } }, objectIdentifier: project_phid)
      updater.update_custom_fields(project_attrs)
    end
  end

  describe '#create_or_update_project' do
    let(:expected_update_slugs_body) do
      Api::Conduit::BodyFormatter
        .transactions([
                        [:slugs, [slug]]
                      ]).merge(objectIdentifier: project_phid)
    end
    let(:expected_update_body) do
      Api::Conduit::BodyFormatter
        .transactions([
                        %i[subtype sourcecode],
                        [:description, ''],
                        [:name, event['name'].capitalize],
                        [:slugs, [slug]]
                      ]).merge(objectIdentifier: project_phid)
    end

    it 'creates project' do
      allow(updater).to receive(:phabricator_project).and_return(nil)
      aggregate_failures do
        expect(Api::Conduit).to receive(:project_edit).with(
          Api::Conduit::BodyFormatter
          .transactions([
                          %i[subtype sourcecode],
                          [:description, ''],
                          [:name, event['name'].capitalize],
                          [:slugs, [slug]],
                          [:space, ::Api::Conduit.space_phid]
                        ])
        ).and_return(project_attrs)
        expect(updater).to receive(:update_custom_fields)
      end
      updater.create_or_update_project
    end

    it 'updates project' do
      allow(updater).to receive(:phabricator_project).and_return(project_attrs)
      aggregate_failures do
        expect(Api::Conduit).to receive(:project_edit).with(
          expected_update_body
        ).and_return(project_attrs)
        expect(Api::Conduit).to receive(:project_edit).with(
          expected_update_slugs_body
        ).and_return(project_attrs)
        expect(updater).to receive(:update_custom_fields)
      end
      updater.create_or_update_project
    end
  end
end
