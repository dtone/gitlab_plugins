# How to fix known issues manualy

Maybe you did something before you wanted to follow steps bellow. In example you rename the duplicit project to new name. So you need to rename Project in Phabricator to the original value and remove new slugs. Than you can continue by steps.
When you use Conduit API to edit project slugs you need to call it twice if you don't want to preserve previous slugs.An example if changing name and slugs 
```
curl -X POST https://phabricator.dtone.com/api/project.edit -H 'Accept: */*' -H 'Content-Type: application/x-www-form-urlencoded' -d 'api.token=API_TOKEN&objectIdentifier=PROJECT_PHID&transactions%5B0%5D%5Btype%5D=slugs&transactions%5B0%5D%5Bvalue%5D%5B0%5D=NEW_SLUG&transactions%5B1%5D%5Btype%5D=name&transactions%5B1%5D%5Bvalue%5D=NEW_NAME'
```

## Two GitLab projects with the same name

In current implementation is not allowed because it's not possible to chose which is correct.
If you create a project in GitLab with name which already exists you are supposed to do few steps to fix this state.

**Prerequisites if you don't have permissions to edit objects in Phabricator and you must use Conduit API (Phabricator API):**
- `API_TOKEN` for Phabricator API call
- `PROJECT_PHID` PHID of project in Phabricator you can find it by [API](https://secure.phabricator.com/conduit/method/project.search/)
  - if you know ID of the project `curl -X POST https://phabricator.dtone.com/api/project.search -H 'Content-Type: application/x-www-form-urlencoded' -H 'cache-control: no-cache' -d 'api.token=API_TOKEN&constraints%5Bids%5D%5B0%5D=11'`
  - if you know slug of the project `curl -X POST https://phabricator.dtone.com/api/project.search -H 'Content-Type: application/x-www-form-urlencoded' -H 'cache-control: no-cache' -d 'api.token=API_TOKEN&constraints%5Bslugs%5D%5B0%5D=k8s'`

### Steps

1. remove `.gitlab-plugins.yml` file from the duplicit GitLab project
2. remove Phabricator tags from diffusion repository in Phabricator for the duplicit GitLab project if it was set
3. remove URLs to GitLab in diffusion repository in Phabricator of the duplicit GitLab project if the URLs were set
4. change subtype of project in Phabricator if it should be a different (deffault, sourcecode and other subtypes)
  - use UI or [API](https://secure.phabricator.com/conduit/method/project.edit/) it depends on permissions
  `curl -X POST https://phabricator.dtone.com/api/project.edit -H 'Content-Type: application/x-www-form-urlencoded'  -d 'api.token=API_TOKEN&objectIdentifier=PROJECT_PHID&transactions%5B0%5D%5Btype%5D=subtype&transactions%5B0%5D%5Bvalue%5D=default'`
5. rename the duplicit GitLab project -> this trigger a new event to create project and repository in Phabricator with a new name
6. check tags on diffussion repositories in Phabricator and fill the right if some are missing

## You were noticed that branch does not content ID of Phabricator task

You can use one of them fix

- rename branch and update merge request
- add a ticket ID to the title of merge request
- add a ticket ID to the description of merge request

## Your branch related invalid ticket ID

- rename branch and update merge request