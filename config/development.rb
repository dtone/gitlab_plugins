# frozen_string_literal: true

# place to require extend notifiers
require_relative '../lib/notifiers/slack/slack_notifier'

DT1::Config.setup do
  #
  # it's not recommended paste token to envs
  # because your secrets can leak via bash history
  # use envs only for development
  #
  # GitLab API configuration
  gitlab.endpoint = ENV['GITLAB_API_ENDPOINT'] || '' # typical value te test on localhost 'http://127.0.0.1:80/api/v4'
  gitlab.ssh_domain = 'git.dtone.xyz' # gitlab url used as ssh domain
  # private tokens of the gitlab plugin bot in GitLab
  gitlab.private_token = ENV['GITLAB_API_PRIVATE_TOKEN'] || ''
  # paste project GitLab ID projects to
  # :allow - events
  # repository.view - view rights in Phabricator
  #                 - :users, :administrator or PHID
  # repository.edit - edit rights in Phabricator - default users
  #                 - :users, :administrator or PHID
  gitlab.projects = {
    '6' => { # ops/puppet
      allow: %w(merge_request project_update),
      repository: {
        view: 'PHID-PROJ-wgiarbe5x7e3lnpvwagf', # fresco group
        edit: :administrator
      }
    }
  }
  # Conduit API configuration
  conduit.endpoint = ENV['CONDUIT_API_ENDPOINT'] || '' # typical value to test on localhost 'http://127.0.0.1:81/api'
  conduit.phabricator_url = '' # typical value to test on localhost 'http://127.0.0.1:81'
  # private token of the gitlab plugin bot in Phabricator
  conduit.private_token = ENV['CONDUIT_API_ACCESS_TOKEN'] || ''
  conduit.space_phid = '' # space PHID in Phabricator where to create objects
  conduit.ssh_phid = '' # PHID of ssh keys stored in Phabricator
  # Logger configuration
  logger.outputter = STDOUT
  # you can use own Logger Formater to details see https://ruby-doc.org/stdlib-2.6.4/libdoc/logger/rdoc/Logger/Formatter.html
  # TODO change DT1::Logger::JsonFormatter to difference module name as default
  logger.formatter = DT1::Logger::JsonFormatter.new
  logger.log_level = ENV['LOG_LEVEL'] || ::Logger::DEBUG # default ::Logger::INFO
  logger.progname = 'gitlab_plugins'
  # Notifiers
  # you can add own Notifier - the format is described in Readme.md
  # notification to Slack App
  slack = SlackNotifier.new(
    allow_notify: true, # enable/disable send message to Slack
    invite: false, # invite people by email
    channel: '', # id of channel in Slack
    mention: false, # mention people in messages
    mention_level: :warn, # notify messages with log level and higher
    oauth_access_token: '', # slack oauth access toke to send message
    webhook: '', # web hook for Slack channel related to the SlackNotifier
    workspace: '' # workspace in Slack
  )
  notifiers << slack
  #
  # Listener configuration per event type
  # listeners are ran in paste order
  # you can create a chain of listeners
  # it means that if some listener in a chain failed the other in chain are not ran
  events['project_create'] = [
    [PhabricatorUpdater::ProjectCreateListener, PhabricatorUpdater::DiffusionRepositoryCreateListener]
  ]
  events['project_destroy'] = []
  events['project_rename'] = [
    [PhabricatorUpdater::ProjectUpdateListener, PhabricatorUpdater::DiffusionRepositoryUpdateListener]
  ]
  events['project_transfer'] = []
  events['project_update'] = [
    [PhabricatorUpdater::ProjectUpdateListener, PhabricatorUpdater::DiffusionRepositoryUpdateListener]
  ]
  # events['user_add_to_team'] = []
  # events['user_remove_from_team'] = []
  # events['user_create'] = []
  # events['user_destroy'] = []
  # events['user_failed_login'] = []
  # events['user_rename'] = []
  # events['key_create'] = []
  # events['key_destroy'] = []
  events['group_create'] = [
    [PhabricatorUpdater::GroupCreateListener]
  ]
  events['group_destroy'] = []
  events['group_rename'] = [] # seems that evetnt is not fired on rename
  # events['user_add_to_group'] = []
  # events['user_remove_from_group'] = []
  events['merge_request'] = [
    [PhabricatorUpdater::DifferentialUpdateListener]
  ]
end
