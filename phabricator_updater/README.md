# Phabricator Updater

## Create or update `project` and `repository` in Phabricator by event from GitLab.

### Filter events per project

- Personal projects (kind of project namespace is `user`) are skipped.
- Specific projects and specific events can be filtered. The example bellow shows processing only merge requests for project 123.

```ruby
...
  gitlab.projects = {
    '123' => {
      allow: %w(merge_request)
    }
  }
  ...
```

### Project policy

Phabricator updater creates repositories with `view` policy by default set to `user` if the GitLab kind of namespace is `public` or `internal`. Default behavior for `private` GitLab kind of namespace is set `view` and `edit` to `admin`.
Because some projects can contain passwords, tokens and other secrets and some users need to use these secrets the project can set own policy. To make repository visible only to some group you can add permissions into configuration file `config/config.rb`. It allows set predefined Phabricator value like `user, admin` or push PHID of group or role. The example bellow shows how to set policy `view` only to project members and `edit` policy to `admin`.

```ruby
  ...
  gitlab.projects = {
    '123' => {
      repository: {
        view: 'PHID-PROJ-bgiarbe5x7e3lnpvwagf',
        edit: :admin
      }
    }
  }
  ...
```
### Common issues

- Were you warned about duplicate project name? Go to GitLab and to edit file `.gitlab_plugins`. To this file into JSON path `$.phabricator.project.name` write a name which not will be duplicate. Example for `ACS` project add name `ACS project`. Example of whole JSON `{"gitlab":{"project":{"id":99}},"phabricator":{"project":{"id":105,"phid":"PHID-PROJ-4odxsnvlzt6k2wchlfrf", "name":"ACS project"}}}`

## Create `diff` in Phabricator by event from GitLab

- Were you warned about missing ticket id? You can fix it by filling a ticket ID to the title or description of merge request. ID is in full format e.g. `T9232`.
- Did you assigned a bad ticket ID? You are supposed to rename branch or change a ticket ID in the title or description of merge request.
- Do you need more reviewers of a merge request? This function is paid in GitLab CE. Well, we hijacked this feature. You can mention people in merge request description e.g. `@frantisek.svoboda` and if user has same name in Phabricator it will be assigned as another reviewer. You can mention more than one people.
