# frozen_string_literal: true
# TODO
# describe the purpose of this script
require 'base64'
require 'gitlab'
require 'json'
require 'oj'
require 'pp'

::Gitlab.endpoint = ENV['GITLAB_API_ENDPOINT']
::Gitlab.private_token = ENV['GITLAB_API_PRIVATE_TOKEN']

def browse_pages(group_page_size = 50, group_page = 0)
  loop do
    page = yield(group_page_size, group_page)

    break page.size < group_page_size
  end
end

pha_phids = {}

browse_pages(50, 0) do |group_page_size, group_page|
  page = Gitlab.groups(per_page: group_page_size, page: group_page)
  page.each do |group|
    Gitlab.group_projects(group.id,
                          per_page: group_page_size).each_page do |projects|
      projects.each do |project|
        file_content = Gitlab.get_file(project.id, '.gitlab_plugins', :master).content
        attrs = Oj.load(Base64.decode64(file_content))
        pha_phids[attrs['phabricator']['project']['phid']] ||= []
        pha_phids[attrs['phabricator']['project']['phid']] << project.path
      rescue StandardError
        puts "#{project.path} #{$ERROR_INFO}"
      end
    end
  end
  page
end

pp pha_phids
puts 'duplicate :-O' if pha_phids.values.any? { |a| a.size > 1 }
