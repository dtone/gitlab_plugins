# frozen_string_literal: true

require 'socket' # to get hostname

require_relative '../../lib/conduit/conduit'
require_relative '../../lib/conduit/utils'
require_relative 'state_helper'

# TODO: should updater really sit under /helper dir?
module PhabricatorUpdater
  # class managed Revisons belongs to tickets
  # task id must be in branch name
  # rubocop:disable Metrics/ClassLength
  class DifferentialUpdater
    include ::DT1::GitLabFileStorage
    include GitLabHelper
    include PhabricatorHelper
    include StateHelper

    HUNKS_REGEXP = /^-(?<old_offset>\d+)(?:,(?<old_length>\d+))?\s\+
                    (?<new_offset>\d+)(?:,(?<new_length>\d+))
                    ?\s@@(?:\s.*?)?$/x.freeze
    INVALID_BRANCH_NAME_MSG = 'Branch (%<branch>s) either MR (%<title>s) ' \
                              'name does not contain any ID of existing ' \
                              'Phabricator task.'
    REGEXP_MENTION_USER = /(?<=\s|^)@([a-z0-9]+\.[a-z0-9]+)/.freeze
    REGEXP_TASK_ID = /(?<=T)(\d+)/i.freeze
    USERS_TO_IGNORE = %w[infra+phabricatorbot bot].freeze

    def initialize(event, gitlab_mr)
      @gitlab_event = event
      @gitlab_mr = gitlab_mr
    end

    def skip_merge_request?
      @gitlab_mr.source_branch.to_sym == UPDATE_BRANCH_NAME
    end

    def update
      return if skip_merge_request?

      @gitlab_attrs = Gitlab.project(@gitlab_mr.project_id)
      return if skip_project?

      project_attrs = project_by_phid_in_gitlab!(@gitlab_mr.project_id)
      repository_attrs = search_repository_by_project!(project_attrs).first
      assignees = find_phabricator_assignees(@gitlab_mr.assignees)
      author_attrs = find_phabricator_author
      task_attrs = search_maniphest
      revisions = search_revision(task_attrs, author_attrs, repository_attrs)

      create_or_update_revision(revisions, repository_attrs,
                                assignees.map { |a| a['phid'] },
                                [task_attrs['phid']])
      nil # does not report anything to slack
    end

    def phab_user_name_from_email(email)
      email.split('@').first
    end

    def find_phabricator_assignees(gitlab_assignees)
      assignees_git = gitlab_assignees.map do |user|
        Gitlab.user(user['id'])
      end
      # flatten because regexp group
      cc_names = @gitlab_mr.description.to_s
                           .scan(REGEXP_MENTION_USER).flatten

      assignee_emails = assignees_git.map(&:email)
      assignee_emails = assignee_emails.map { |e| phab_user_name_from_email(e) }
                                       .concat(cc_names).uniq

      search_users_by_query(assignee_emails)
    end

    def search_users_by_query(user_names)
      user_names = Array(user_names)
      USERS_TO_IGNORE.each { |bot| user_names.delete(bot) }
      return [] if user_names.empty?

      user_names.map do |user_name|
        Api::Conduit.user_search(constraints: { query: user_name })
      end.flatten
    end

    def author_email
      return @author_email if @author_email

      author_git = Gitlab.user(@gitlab_mr.author.id)
      @author_email = author_git.email
    end

    def throw_user_not_found(message_type)
      throw(:error,
            type: message_type,
            text: format('User (%<user>s) was not found in Phabricator.',
                         user: author_email),
            urls: [['Merge request', @gitlab_mr.web_url]],
            user: { email: author_email })
    end

    def find_phabricator_author
      author_name = phab_user_name_from_email(author_email)
      throw_user_not_found(:info) if USERS_TO_IGNORE.include?(author_name)

      authors = search_users_by_query(author_name)
      if authors.size == 1
        authors.first
      elsif authors.size > 1
        DT1::Logger.warn(message: 'Cannot find author of MR in Phabricator.',
                         user: { email: author_email },
                         result: { raw: authors.to_json })
        authors.first
      elsif authors.empty?
        DT1::Logger.error(message: 'Cannot find author of MR in Phabricator.',
                          user: { email: author_email },
                          result: { raw: authors.to_json })
        throw_user_not_found(:error)
      end
    end

    def search_maniphest
      task_id = @gitlab_mr.source_branch[REGEXP_TASK_ID] ||
                @gitlab_mr.title[REGEXP_TASK_ID] ||
                @gitlab_mr.description.to_s[REGEXP_TASK_ID]

      unless task_id
        throw(:error,
              type: :warn,
              text: format(INVALID_BRANCH_NAME_MSG,
                           branch: @gitlab_mr.source_branch,
                           title: @gitlab_mr.title),
              urls: [['Merge request', @gitlab_mr.web_url]],
              user: { email: author_email })
      end

      tasks = Api::Conduit.maniphest_search(constraints: { ids: [task_id] },
                                            attachments: { projects: true })
      return tasks.first unless tasks.empty?

      throw(:error,
            type: :warn,
            text: format(INVALID_BRANCH_NAME_MSG,
                         branch: @gitlab_mr.source_branch,
                         title: @gitlab_mr.title),
            urls: [['Merge request', @gitlab_mr.web_url]],
            user: { email: author_email })
    end

    def revision_title
      "#{revision_title_start_with}_#{@gitlab_mr.title}"
    end

    def revision_title_start_with
      "#{@gitlab_mr.project_id}/#{@gitlab_mr.iid}"
    end

    def search_revision(_task_attrs, _author_attrs, repository_attrs)
      Api::Conduit.differential_revision_search(
        constraints: {
          repositoryPHIDs: [repository_attrs['phid']],
          query: "title:#{revision_title_start_with}"
        }
      )
    end

    def create_diff(repository_attrs)
      Api::Conduit.create_diff(
        branch: @gitlab_mr.source_branch,
        changes: to_arcanist_changes,
        lintStatus: 'none', # it should be by CI/CD
        sourceControlBaseRevision: @gitlab_mr.diff_refs.base_sha,
        # $repository_api->getSourceControlPath(); ArcanistGitAPI - null
        sourceControlPath: nil,
        sourceControlSystem: :git,
        sourceMachine: Socket.gethostname,
        # ArcanistRepositoryAPI - getPath(); usually directory separator
        sourcePath: "#{Dir.getwd}/",
        unitStatus: 'none', # it should be by CI/CD
        # optional parameters
        bookmark: nil, # only mercurial
        creationMethod: 'gitlab_plugins',
        repositoryPHID: repository_attrs['phid']
      )
    end

    def create_or_update_revision(revisions, repository_attrs,
                                  assignees_phids, task_phids)
      revision, revision_phid = nil
      # acranist create diff everytime
      diff_phid = create_diff(repository_attrs)['phid']

      unless revisions.empty?
        revision = revisions.first
        revision_phid = revision['phid']
      end

      attrs = revision_attributes(diff_phid,
                                  assignees_phids, task_phids,
                                  repository_attrs)

      created_object_attrs = Api::Conduit.differential_revision_edit(
        Api::Conduit::BodyFormatter.transactions(attrs).tap do |a|
          a[:objectIdentifier] = revision_phid if revision_phid
        end
      )
      revision_phid ||= created_object_attrs['phid']
      set_states(revision, revision_phid)

      created_object_attrs
    end

    def set_states(current_revision, revision_phid)
      state_steps = state_by_mr(@gitlab_mr, current_revision)
      state_steps.each do |state_step|
        Api::Conduit.differential_revision_edit(
          Api::Conduit::BodyFormatter.transactions([state_step]).tap do |a|
            a[:objectIdentifier] = revision_phid
          end
        )
      end
    end

    def revision_attributes(diff_phid, assignees_phids,
                            task_phids, repository_attrs)
      project_phids = repository_attrs.dig(
        'attachments', 'projects', 'projectPHIDs'
      )
      [
        [:'projects.set', project_phids],
        [:update, diff_phid], [:title, revision_title],
        [:summary,
         "[[#{@gitlab_mr.web_url} | GitLab MR]]"],
        [:'reviewers.set', assignees_phids],
        [:repositoryPHID, repository_attrs['phid']],
        [:'tasks.set', task_phids], [:testPlan, 'skip'],
        %i[view users], %i[edit administrator]
      ]
    end

    def make_change(diff)
      match_hashs = diff['diff'].match(/commit (?<hash>[a-f0-9]+)/)
      # fill old path only if it's different
      old_path = if diff['new_path'] == diff['old_path']
                   nil
                 else
                   diff['old_path']
                 end
      {
        # no idea when to send metadata, but usually must be send as hash
        # it's not possible to send empty hash so some fake value is good
        metadata: { fake: :fake },
        oldPath: old_path,
        currentPath: diff['new_path'],
        awayPaths: nil,
        oldProperties: { 'unix:filemode' => diff['a_mode'] },
        newProperties: { 'unix:filemode' => diff['b_mode'] },
        type: type_by_state_of_file(diff),
        fileType: diff['diff'].match?(/^Binary files/) ? 3 : 1,
        commitHash: match_hashs ? match_hashs[:hash] : nil
      }
    end

    def make_hungs(diff)
      diff['diff'].split(/^@@ /).map do |hunk|
        next if hunk.empty?

        match_hunks = hunk.match(HUNKS_REGEXP)
        add_lines = hunk.split("\n").count { |l| l.start_with?('+') }
        del_lines = hunk.split("\n").count { |l| l.start_with?('-') }
        next nil unless match_hunks

        {
          'oldOffset' => match_hunks[:old_offset],
          'newOffset' => match_hunks[:new_offset],
          'oldLength' => match_hunks[:old_length] || match_hunks[:old_offset],
          'newLength' => (
            match_hunks[:new_length] || match_hunks[:new_offset]
          ).to_i,
          'addLines' => add_lines,
          'delLines' => del_lines,
          'isMissingOldNewline' => false,
          'isMissingNewNewline' => false,
          'corpus' => ' ' + hunk.partition(/ @@/).last
        }
      end.compact
    end

    # experimental set of changes
    # ArcanistDiffWorkflow.php
    # private function getDiffOntoTargets() {
    def to_arcanist_changes
      changes = {}
      versions = Gitlab.merge_request_diff_versions(@gitlab_mr.project_id,
                                                    @gitlab_mr.iid)
      last_version = versions.max_by(&:id)
      version = Gitlab.merge_request_diff_version(@gitlab_mr.project_id,
                                                  @gitlab_mr.iid,
                                                  last_version.id)

      version.diffs.each do |diff|
        change = make_change(diff)
        change[:hunks] = make_hungs(diff)

        changes[diff['new_path']] = change
      end
      # DT1::Logger.debug(changes: changes.to_json)
      changes
    end

    # see ArcanistDiffChangeType.php
    # and ArcanistDiffParser.php
    def type_by_state_of_file(diff)
      return 1 if diff['new_file']
      return 6 if diff['renamed_file']
      return 3 if diff['deleted_file']

      2 # other like change
    end
  end
  # rubocop:enable Metrics/ClassLength
end
