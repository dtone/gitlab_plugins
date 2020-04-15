# frozen_string_literal: true

module PhabricatorUpdater
  # modules helps to select how to change state of revision
  module StateHelper
    # it's like a graph with current states
    # the first level is a current state of MR
    # the second level is a current WIP state of MR
    # the third level is a current state of revision
    # the result how to set a new state of revision by the current MR state
    #
    # Revision states
    # plan-changes, request-review, close, reopen,
    # abandon, accept, reclaim, reject, commandeer, resign
    #
    GRAPH = {
      'opened' => {
        true => {
          'closed' => [[:reopen, true], [:'plan-changes', true]],
          'abandoned' => [[:reclaim, true], [:'plan-changes', true]],
          'accepted' => [[:'plan-changes', true]], # maybe nothing
          'needs-review' => [[:'plan-changes', true]],
          'needs-revision' => [[:'plan-changes', true]],
          'changes-planned' => [],
          'draft' => [[:'plan-changes', true]],
          # no revision - default state
          'default' => [[:'plan-changes', true]]
        },
        false => {
          'closed' => [[:reopen, true]],
          'abandoned' => [[:reclaim, true]],
          'accepted' => [[:'request-review', true]], # maybe nothing
          'needs-review' => [],
          'needs-revision' => [],
          'changes-planned' => [[:'request-review', true]],
          'draft' => [[:'request-review', true]],
          # no revision - default state
          'default' => []
        }
      },
      'closed' => {
        true => {
          'closed' => [],
          'abandoned' => [],
          'accepted' => [[:abandon, true]],
          'needs-review' => [[:abandon, true]],
          'needs-revision' => [[:abandon, true]],
          'changes-planned' => [[:abandon, true]],
          'draft' => [[:abandon, true]],
          # no revision - default state
          'default' => [[:abandon, true]]
        },
        false => {
          'closed' => [],
          'abandoned' => [],
          'accepted' => [[:abandon, true]],
          'needs-review' => [[:abandon, true]],
          'needs-revision' => [[:abandon, true]],
          'changes-planned' => [[:abandon, true]],
          'draft' => [[:abandon, true]],
          # no revision - default state
          'default' => [[:abandon, true]]
        }
      },
      'merged' => {
        true => {
          'closed' => [],
          'abandoned' => [],
          'accepted' => [[:close, true]],
          'needs-review' => [[:accept, true], [:close, true]],
          'needs-revision' => [[:'request-review', true], [:accept, true],
                               [:close, true]],
          'changes-planned' => [[:'request-review', true], [:accept, true],
                                [:close, true]],
          'draft' => [[:accept, true], [:close, true]],
          'published' => [],
          # no revision - default state
          'default' => [[:accept, true], [:close, true]]
        },
        false => {
          'closed' => [],
          'abandoned' => [],
          'accepted' => [[:close, true]],
          'needs-review' => [[:accept, true], [:close, true]],
          'needs-revision' => [[:'request-review', true], [:accept, true],
                               [:close, true]],
          'changes-planned' => [[:'request-review', true], [:accept, true],
                                [:close, true]],
          'draft' => [[:'request-review', true], [:accept, true],
                      [:close, true]],
          'published' => [],
          # no revision - default state
          'default' => [[:accept, true], [:close, true]]
        }
      },
      'locked' => { # CI/CD are running next event set right state
        true => Hash.new([]),
        false => Hash.new([])
      }
    }.freeze

    def state_by_mr(gitlab_mr, revision)
      gitlab_path = GRAPH.fetch(gitlab_mr.state)
                         .fetch(gitlab_mr.work_in_progress)
      diff_state = if revision
                     revision['fields']['status']['value']
                   else
                     'default'
                   end

      states = gitlab_path[diff_state]

      return states if states

      raise("Unknown transition: #{gitlab_path} ?? #{diff_state}")
    end
  end
end
