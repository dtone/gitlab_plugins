# frozen_string_literal: true

# place to require extend notifiers
require_relative '../lib/notifiers/slack/slack_notifier'

DT1::Config.setup do
  #
  # GitLab API configuration
  gitlab.endpoint = ENV['GITLAB_API_ENDPOINT']
  gitlab.ssh_domain = ENV['GITLAB_SSH_DOMAIN']
  # private tokens are for testing only
  gitlab.private_token = ENV['GITLAB_API_PRIVATE_TOKEN']
  # paste project GitLab ID projects to
  # :allow - events
  # repository.view - view rights in Phabricator
  #                 - :users, :admin or PHID
  # repository.edit - edit rights in Phabricator - default users
  #                 - :users, :admin or PHID
  gitlab.projects = {
    '6' => { # ops/puppet
      allow: %w(merge_request project_update),
      repository: {
        view: 'PHID-PROJ-wgiarbe5x7e3lnpvwagf',
        edit: :admin
      }
    }
  }
  # Conduit API configuration
  conduit.endpoint = ENV['CONDUIT_API_ENDPOINT']
  conduit.phabricator_url = ENV['CONDUIT_PHABRICATOR_URL']
  conduit.private_token = ENV['CONDUIT_API_PRIVATE_TOKEN']
  conduit.space_phid = ENV['CONDUIT_SPACE_PHID']
  conduit.ssh_phid = ENV['CONDUIT_SSH_PHID']
  # Logger configuration
  logger.outputter = STDOUT
  logger.formatter = DT1::Logger::JsonFormatter.new
  logger.log_level = ENV['LOG_LEVEL'] || ::Logger::INFO
  logger.progname = 'gitlab_plugins'
  # Notifiers
  # you can add own Notifier - the format is described in Readme.md
  # notification to Slack App
  slack = SlackNotifier.new(
      allow_notify: ENV.fetch('SLACK_NOTIFY', 'true') == 'true',
      invite: false,
      channel: ENV['SLACK_CHANNEL'],
      mention: false,
      mention_level: :warn,
      oauth_access_token: ENV['SLACK_ACCESS_TOKEN'],
      webhook: ENV['SLACK_WEBHOOK_URL'],
      workspace: ENV['SLACK_WORKSPACE']
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
