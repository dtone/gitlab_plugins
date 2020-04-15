# GitLab Plugins

Collection of ACS GitLab plugins. To understand how plugins work check [GitLab documentation](https://docs.gitlab.com/ee/administration/plugins.html).

## How to install to the GitLab

The short way is to use Dockerfile to build a docker image and then run a docker container.

Or the long and complicated way is to copy the whole project to the folder where you want to have the source codes of GitLab plugins. e.g. `/opt/dtone/gitlab_plugins`.
You can install gems to your Ruby environment or you can install own Ruby for plugins.
Some gems need the `ruby-dev` package. GitLab does not have the `ruby-dev` embedded.

Tar project `tar --exclude=vendor --exclude=config -cvf gitlab_plugins.tar *` and copy to server `cat gitlab_plugins.tar | ssh root@svc01.fi.dtone.xyz "cat > /tmp/gitlab_plugins.tar"` and extract on the server `tar -C /opt/dtone/gitlab_plugins -xvf /tmp/gitlab_plugins.tar`

### Recommended Ruby and gems installation

Install Ruby 2.5 and higher install bundler `gem install bundler` and install gem `bundle` (all in `/opt/dtone/gitlab_plugins` folder).

Move `run` file into GitLab plugins e.g. `mv run /opt/gitlab/embedded/service/gitlab-rails/plugins/dtone_gitlab_plugins`.
Edit variable `PLUGIN_SOURCE_DIR` in `run` file to folder with source codes. Change used Ruby environment if you have installed own Ruby. Change the owner of `dtone_gitlab_plugins` to the `git` user.

### GitLab event handling

GitLab emits all events for all registered plugins as its process. This could be a bit overwhelmed for a server (too many processes if you have a lot of plugins). Too many skip conditions if the event is not for your plugin.
GitLab plugins project is one plugin that allows writing simple plugins in Ruby(for now). It allows run only selected plugins per event type.

## How to run GitLab plugins

You can run GitLab plugins run as

- a process `make run`
- a docker container `make run-docker` (you need build docker image `make build`)

It's possible to run with GitLab plugins for the specific environment by setting `ENVIRONMENT` variable.

- using pure Ruby command `ENVIRONMENT=production bundle exec ruby plugins.rb`
- using make file and run as docker container `make run-docker ENVIRONMENT=staging`

## How to send an event with a specific project

Very simple just send JSON to STDIN of the running TCP server. If GitLab plugins runs

- on localhost or in docker container on localhost with default port just run `make emit-event EVENT='{"event_name" : "project_update", "project_id": 173 }'`
- on some hostname and different port just run `make emit-event EVENT='{"event_name" : "project_update", "project_id": 173 }' HOST=glp.dtone.xyz PORT=2389`

## Configuration and overrides

The configuration is in a file `config/<ENVIRONMENT>.rb` and it's self-describing. Configuration allows setup notifiers (e.g. SlackNotifier), listeners per events, secrets, and URLs to setup APIs to GitLab and Phabricator and logging.

It's possible to store your configuration in dotenv files with the same name as an environment. For example, run GitLab plugins in the `development` environment allowing override environment variables with file `development.env`. It's very useful instead of pasting envs variables in the command line.

In development mode, it is useful to have set up against the local installation of GitLab and Phabricator. To run GitLab and Phabricator on localhost you can use the setup for Docker compose in `utils/docker-compose.yml`.


## How to run GitLab plugins

You can run GitLab plugins run as

- a process `make run`
- a docker container `make run-docker` (you need build docker image `make build`)

It's possible to run with GitLab plugins for specific environment by setting `ENVIRONMENT` variable.

- using pure Ruby command `ENVIRONMENT=production bundle exec ruby plugins.rb`
- using make file and run as docker container `make run-docker ENVIRONMENT=staging`

## How to send event with specific project

Very simple just send JSON to STDIN of the running TCP server. If GitLab plugins runs

- on localhost or in docker container on localhost with default port just run `make emit-event EVENT='{"event_name" : "project_update", "project_id": 173 }'`
- on some hostname and different port just run `make emit-event EVENT='{"event_name" : "project_update", "project_id": 173 }' HOST=glp.dtone.xyz PORT=2389`

## Configuration and overrides

Configuration is in a file `config/<ENVIRONMENT>.rb` and it's self-describing. Configuration allows setup notifieres (e.g. SlackNotifier), listeners per events, secrets and URLs to setup APIs to GitLab and Phabricator and logging.

It's possible to store your configuration in dotenv files with same name as an environment. For example run GitLab plugins in `development` environment allows override environment variables with file `development.env`. It's very usefull instead of pasting envs variables in command line.

In development mode it is useful to have setup against local installation of GitLab and Phabricator. To run GitLab and Phabricator on localhost you can use setup for Docker compose in `utils/docker-compose.yml`.


## Phabricator Updater plugin

This plugin creates objects in Phabricator according to the below rules.

- Creates Project in Phabricator for every group in GitLab
  - Sets slug for this project by GitLab group name
  - Sets URL to GitLab group
- Creates Project in Phabricator for every repository in GitLab
  - Sets slug for this project by GitLab group and project name
  - Sets URL to GitLab project
  - Sets URL to Diffusion Repository
- Creates Diffusion repository in Phabricator
  - Sets slugs(tags) by "group" project and "repository" project in Phabricator
  - Sets GitLab repository URL to this Diffusion repository
- Update Projects in Phabricator by changes in GitLab projects/repositories
  - Sets slug for this project by GitLab project part of URL

This plugin does not

- Does not update projects by changes in GitLab groups

[Readme](phabricator_updater/README.md) / [TroubleShooting](phabricator_updater/TROUBLESHOOTING.md)

### Add extensions to Phabricator

This plugin uses [Phabricator custom-fields](https://secure.phabricator.com/book/phabricator/article/custom_fields/) with definitions that are stored in folder `phabricator_updater/phabricator_extensions`.

## Initialize projects in Phabricator after installation

When you install the plugin to GitLab you don't have any projects in Phabicator. To import all projects by your GitLab structure you can use script `utils/gitlab/emit_events.rb`. It's written to create all projects (`project_create` event is used in the script).

## How to write another listener

First, you need to require your listener. Then you need to register your listener in `config/config.rb` for a related event. You can register one listener or batch of listeners which one depends on previous. Your listeners should respond to method `notify(event)`. The event argument is a GitLab JSON event parsed into a Hash.

If you need to notify your system after finishing the listener you can return *report* object from a listener.

### Format of the report object

It is a hash with keys for your Notifiers for example in our SlackNotifier:

- `:event` event in GitLab raw JSON format, it is used as the text of Slack message
- `:pretext` short text used in our SlackNotifier as the pretext in Slack attachments
- `:text` main text of the report, it can be used for place stackt races or events
- `:title` key for the subject of your reports
- `:type` a kind of the report `:info`, `:warn`, `error` and you can add own for your notifiers
- `:urls` array of pairs `text` and `url` to what you need in example a link to created repository in Phabricator

## How to write another notifier

There is a folder `lib/notifiers` to add another notification. After adding notifier there you need to update `config/config.rb` to require your file and register class/instance e.g. for simple Slack notifications `notifiers << slack`. Your class/instance should respond to method `notify(report)`.

- TODO create parents and load files without modifying config.
