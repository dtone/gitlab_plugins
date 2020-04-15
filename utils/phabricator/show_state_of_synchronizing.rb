# frozen_string_literal: true

require 'gitlab'
require 'pp'

require_relative '../../lib/gitlab_file_storage'
require_relative '../../phabricator_updater/phabricator_updater.rb'

::Gitlab.endpoint = ENV['GITLAB_API_ENDPOINT'] || raise
::Gitlab.private_token = ENV['GITLAB_API_PRIVATE_TOKEN'] || raise
::Api::Conduit.endpoint = ENV['CONDUIT_API_ENDPOINT'] || raise
::Api::Conduit.private_token = ENV['CONDUIT_API_ACCESS_TOKEN'] || raise

def browse_pages(group_page_size = 50, group_page = 0)
  loop do
    page = yield(group_page_size, group_page)

    break page.size < group_page_size
  end
end

def search_project_by_slugs(slugs)
  Api::Conduit.project_search(constraints: { slugs: slugs })
end

hash_map = { groups: {}, projects: {} } # getilab -> phabricator
browse_pages(50, 0) do |group_page_size, group_page|
  page = Gitlab.groups(per_page: group_page_size, page: group_page)
  page.each do |group|
    puts "#{group.name} (#{group.path})"
    hash_map[:groups][group.name] = search_project_by_slugs(
      [Api::Conduit::Utils.slug_from_name(group.name)]
    )
    Gitlab.group_projects(group.id,
                          per_page: group_page_size).each_page do |projects|
      projects.each do |project|
        hash_map[:projects][project.name] = search_project_by_slugs(
          [Api::Conduit::Utils.make_slug(
              project.name
          )]
        )
      end
    end
  end
  page
end

pp hash_map
