# frozen_string_literal: true

require 'digest'
# it also allows testing requires in phabricator updater
# do not require files in specs
require_relative '../../../support/phabricator_updater_spec_helper'

RSpec.describe PhabricatorUpdater::DifferentialUpdater do
  subject(:updater) do
    described_class.new(event, gitlab_mr)
  end

  let(:event) do
    {
      'object_attributes' => {
        'iid' => mr_id,
        'target_project_id' => project_id
      }
    }
  end
  let(:user1) do
    Gitlab::ObjectifiedHash.new(
      id: '2',
      email: 'john.doe@some.xyz'
    )
  end
  let(:user2) do
    Gitlab::ObjectifiedHash.new(
      id: '2',
      email: 'bob.doe@some.xyz'
    )
  end
  let(:user_author) do
    Gitlab::ObjectifiedHash.new(
      id: '1',
      email: 'john.snow@some.xyz'
    )
  end
  let(:assignees) { [{ 'id' => user1.id }, { 'id' => user2.id }] }
  let(:author) { { 'id' => user_author.id } }
  let(:diff_refs)  do
    Gitlab::ObjectifiedHash.new(
      base_sha: Digest::SHA256.hexdigest('fake master commit')
    )
  end
  let(:mr_id) { '265' }
  let(:project_id) { '666' }
  let(:project_phid) { 'PHIDopopo666' }
  let(:task_id) { '32415' }
  let(:source_branch) { "T#{task_id}_cool_zebra" }
  let(:title) { "T#{task_id} Add Zebra to Safari" }
  let(:web_url) do
    "https://git.some.xyz/group1/project666/merge_requests/#{mr_id}"
  end
  let(:gitlab_mr) do
    Gitlab::ObjectifiedHash.new(
      assignees: assignees,
      author: author,
      description: '',
      diff_refs: diff_refs,
      iid: mr_id,
      project_id: project_id,
      source_branch: source_branch,
      title: title,
      web_url: web_url,
      state: 'opened',
      work_in_progress: false
    )
  end
  let(:diff_phid) { 'PHID02389DIFF' }
  let(:assignees_phids) { %w[PHID2937293 PHID2323243] }
  let(:repository_attrs) do
    { 'phid' => repository_phid, 'attachments' => {
      'projects' => { 'projectPHIDs' => [project_phid] }
    } }
  end
  let(:repository_phid) { 'PHID19089233DS' }
  let(:revision_phid) { 'PHID93U43JDSs' }
  let(:revision_attrs) do
    { 'phid' => revision_phid,
      'fields' => { 'diffPHID' => diff_phid,
                    'status' => { 'value' => 'closed' } } }
  end
  let(:revision_title_start_with) { "#{gitlab_mr.project_id}/#{gitlab_mr.iid}" }
  let(:task_phid) { 'PHIDT12OKIDS' }
  let(:tasks) do
    [
      { 'phid' => task_phid }
    ]
  end
  let(:task_phids) { tasks.map { |t| t['phid'] } }

  before do
    allow(Gitlab).to receive(:user).with(user_author.id).and_return(user_author)
  end

  describe '#phab_user_name_from_email' do
    it 'gets name from email' do
      expect(updater.phab_user_name_from_email('john.doe@some.xyz'))
        .to eq('john.doe')
    end
  end

  describe '#find_phabricator_assignees' do
    it 'finds assignees' do
      aggregate_failures do
        expect(Gitlab).to receive(:user).with(user1.id).and_return(user1)
        expect(Gitlab).to receive(:user).with(user2.id).and_return(user2)
        expect(updater).to receive(:search_users_by_query)
          .with(
            %w[john.doe bob.doe]
          )
      end
      updater.find_phabricator_assignees(assignees)
    end
  end

  describe '#search_users_by_query' do
    it 'searches users in Phabricator', :aggregate_failures do
      expect(Api::Conduit).to receive(:user_search).with(
        constraints: { query: 'john.doe' }
      )
      expect(Api::Conduit).to receive(:user_search).with(
        constraints: { query: 'bob.doe' }
      )
      updater.search_users_by_query(%w[john.doe bob.doe])
    end
  end

  describe '#find_phabricator_author' do
    before do
      allow(Gitlab).to receive(:user).with(user_author.id)
                                     .and_return(user_author)
      allow(Api::Conduit).to receive(:user_search).with(
        constraints: { query: 'john.snow' }
      ).and_return(phab_users)
    end

    context 'with none' do
      let(:phab_users) { [] }

      it 'catches exception' do
        expect do
          updater.find_phabricator_author
        end.to throw_symbol(
          :error,
          hash_including(
            text:
            format(
              'User (%<user>s) was not found in Phabricator.',
              user: user_author.email
            )
          )
        )
      end
    end

    context 'with one' do
      let(:phab_users) { [{ 'phid' => 'PHID9843EJ9FD' }] }

      it 'catches exception' do
        author = updater.find_phabricator_author
        expect(author['phid']).to eq(phab_users.first['phid'])
      end
    end

    context 'with more than one' do
      let(:phab_users) do
        [{ 'phid' => 'PHIDdas234EDFSA' }, { 'phid' => 'PHID0923I9KO' }]
      end

      it 'catches exception' do
        author = updater.find_phabricator_author
        expect(author['phid']).to eq(phab_users.first['phid'])
      end
    end
  end

  describe '#search_maniphest' do
    before do
      allow(Api::Conduit).to receive(:maniphest_search)
        .with(constraints: { ids: [task_id] },
              attachments: { projects: true }).and_return(tasks)
    end

    it 'searches task' do
      expect(updater.search_maniphest).to eq(tasks.first)
    end

    context 'when task does not exist' do
      let(:tasks) { [] }

      it 'raises exception' do
        expect do
          updater.search_maniphest
        end.to throw_symbol(
          :error,
          hash_including(
            text: format('Branch (%<branch>s) either MR (%<title>s) ' \
            'name does not contain any ID of existing ' \
            'Phabricator task.',
                         branch: gitlab_mr.source_branch,
                         title: gitlab_mr.title)
          )
        )
      end
    end

    context 'when source branche and title does not contain taks ID' do
      let(:task_id) { 'zzz' }

      it 'raises exception' do
        expect do
          updater.search_maniphest
        end.to throw_symbol(
          :error,
          hash_including(
            text: format('Branch (%<branch>s) either MR (%<title>s) ' \
            'name does not contain any ID of existing ' \
            'Phabricator task.',
                         branch: gitlab_mr.source_branch,
                         title: gitlab_mr.title)
          )
        )
      end
    end
  end

  describe '#revision_title' do
    it 'builds title of revision' do
      expect(updater.revision_title).to eq(
        "#{gitlab_mr.project_id}/#{gitlab_mr.iid}_#{gitlab_mr.title}"
      )
    end
  end

  describe '#revision_title_start_with' do
    it 'builds prefix of revisions title' do
      expect(updater.revision_title_start_with).to eq(
        "#{gitlab_mr.project_id}/#{gitlab_mr.iid}"
      )
    end
  end

  describe '#create_or_update_revision' do
    it 'creates revision' do
      allow(updater).to receive(:create_diff).and_return(diff_phid)
      expect(Api::Conduit).to receive(:differential_revision_edit)
        .with(hash_excluding(objectIdentifier: anything))
        .and_return('phid' => revision_phid)
      updater.create_or_update_revision([], repository_attrs,
                                        assignees_phids, task_phid)
    end

    context 'when mr is reopen to WIP' do
      let(:gitlab_mr) do
        Gitlab::ObjectifiedHash.new(
          assignees: assignees,
          author: author,
          diff_refs: diff_refs,
          iid: mr_id,
          project_id: project_id,
          source_branch: source_branch,
          title: title,
          web_url: web_url,
          state: 'opened',
          work_in_progress: true
        )
      end

      it 'updates revision' do
        allow(updater).to receive(:create_diff).and_return(diff_phid)
        expect(Api::Conduit).to receive(:differential_revision_edit)
          .with(hash_including(objectIdentifier: anything))
          .and_return('phid' => revision_phid).exactly(3)
        updater.create_or_update_revision([revision_attrs], repository_attrs,
                                          assignees_phids, task_phid)
      end
    end
  end

  describe '#revision_attributes' do
    it 'returns diffs attributes' do
      expect(updater.revision_attributes(diff_phid,
                                         assignees_phids, task_phids,
                                         repository_attrs))
        .to contain_exactly(
          [:'projects.set', [project_phid]],
          [:update, diff_phid],
          [:title, "#{revision_title_start_with}_#{gitlab_mr.title}"],
          [:summary,
           "[[#{gitlab_mr.web_url} | GitLab MR]]"],
          [:'reviewers.set', assignees_phids],
          [:repositoryPHID, repository_phid],
          [:'tasks.set', task_phids], [:testPlan, 'skip'],
          %i[view users], %i[edit administrator]
        )
    end
  end
end
