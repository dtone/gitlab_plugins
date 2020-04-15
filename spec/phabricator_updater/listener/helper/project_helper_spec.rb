# frozen_string_literal: true

class TestProjectHelper
  include PhabricatorUpdater::GitLabHelper
  include PhabricatorUpdater::PhabricatorHelper

  def initialize(project_attrs, gitlab_event)
    @gitlab_attrs = project_attrs
    @gitlab_event = gitlab_event
  end

  def do_job
    return if skip_project?

    'result of job'
  end
end

RSpec.describe PhabricatorUpdater::PhabricatorHelper do
  subject(:tested_instance) { TestProjectHelper.new(gitlab_project, {}) }

  let(:project_id) { 42 }
  let(:gitlab_project) do
    Gitlab::ObjectifiedHash.new(
      namespace: {
        name: 'gitlab_group',
        kind: 'to_fake'
      },
      name: 'project name',
      id: project_id,
      archived: false,
      path_with_namespace: 'group_name/rspec_project'
    )
  end

  describe '#personal_project?' do
    it 'skips personal project' do
      allow(gitlab_project.namespace).to receive(:kind).and_return('user')
      expect(tested_instance.do_job).to be_nil
    end

    it 'does not skip other project' do
      allow(gitlab_project.namespace).to receive(:kind).and_return('group')
      expect(tested_instance.do_job).to eq 'result of job'
    end
  end

  describe '#ignored_project?' do
    it 'skips project' do
      allow(PhabricatorUpdater::Config.gitlab).to receive(:projects)
        .and_return(project_id.to_s => {})
      expect(tested_instance.do_job).to be_nil
    end

    it 'does not skip project' do
      allow(PhabricatorUpdater::Config.gitlab).to receive(:projects)
        .and_return((project_id + 1).to_s => {})
      expect(tested_instance.do_job).to eq 'result of job'
    end
  end

  describe '#all_parent_group_slugs' do
    before do
      allow(Gitlab)
        .to receive(:group)
        .with(12).and_return(Gitlab::ObjectifiedHash.new(
                               name: 'Cool Name',
                               parent_id: 10
                             ))
      allow(Gitlab)
        .to receive(:group)
        .with(10).and_return(Gitlab::ObjectifiedHash.new(
                               name: 'Parent name',
                               parent_id: nil
                             ))
    end

    it 'no parent group' do
      group_slugs = tested_instance
                    .all_parent_group_slugs(Gitlab::ObjectifiedHash.new(
                                              name: 'Group Name',
                                              parent_id: nil
                                            ))
      expect(group_slugs).to contain_exactly('group_name')
    end

    it 'two parent group' do
      group_slugs = tested_instance
                    .all_parent_group_slugs(Gitlab::ObjectifiedHash.new(
                                              name: 'Group Name',
                                              parent_id: 12
                                            ))
      expect(group_slugs)
        .to contain_exactly('group_name', 'cool_name', 'parent_name')
    end
  end
end
