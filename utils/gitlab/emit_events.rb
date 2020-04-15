# frozen_string_literal: true

# this script loads groups/projects in GitLab
# and allows emit GitLab event to trigger GitLab plugins
# if no args
#   - emits events project_create, group_create, merge_request
# if -e | --event
#   - emits only given event - does not check event name
# if -r | --regexp
#   - emits events by rules above only for project/group
#     which match given regular expresion

require 'gitlab'
require 'json'
require 'open3'
require 'pp'

::Gitlab.endpoint = ENV['GITLAB_API_ENDPOINT'] || raise
::Gitlab.private_token = ENV['GITLAB_API_PRIVATE_TOKEN'] || raise

FROM_TIME = Time.new(2020, 01, 22)

def browse_pages(group_page_size = 50, group_page = 0)
  loop do
    page = yield(group_page_size, group_page)

    break page.size < group_page_size
  end
end

def emit_event(event)
  pp event

  Open3.capture3('/home/franta/Projects/office/gitlab_plugins/run', stdin_data: event.to_json)
end

def group_event(group)
  event = {
    event_name: 'group_create',
    group_id: group.id
  }
  emit_event(event)
end

def project_event(project)
  return if FROM_TIME && Time.parse(project.created_at) < FROM_TIME && Time.parse(project.last_activity_at) < FROM_TIME

  event = {
    event_name: 'project_create',
    project_id: project.id
  }

  emit_event(event)
end

def merge_request_event(merge_request)
  return if FROM_TIME && Time.parse(merge_request.created_at) < FROM_TIME && Time.parse(merge_request.updated_at) < FROM_TIME

  event = {
    event_name: 'merge_request',
    object_attributes: {
      target_project_id: merge_request.project_id,
      iid: merge_request.iid

    }
  }

  emit_event(event)
end

regexp = nil
event = nil

ARGV.each_slice(2) do |arg_name, arg_value|
  case arg_name
  when /^(-r)|(--regexp)$/
    regexp = Regexp.new(arg_value)
  when /^(-e)|(--event)$/
    event = arg_value
  end
end

puts "REGEXP: #{regexp}"
puts "EVENT: #{event}"

browse_pages(50, 0) do |group_page_size, group_page|
  page = Gitlab.groups(per_page: group_page_size, page: group_page)
  page.each do |group|
    next if regexp ? !group.path[regexp] : false

    puts group.name

    group_event(group) if event.nil? || (event && event == 'group_create')

    Gitlab.group_projects(group.id,
                          per_page: group_page_size).each_page do |projects|
      projects.each do |project|
        next if regexp ? !project.path_with_namespace[regexp] : false

        puts project.name

        project_event(project) if event.nil? || (event && event == 'project_create')
        Gitlab.merge_requests(project.id).each_page do |merge_request_page|
          merge_request_page.each do |merge_request|
            merge_request_event(merge_request) if event.nil? || (event && event == 'merge_request')
          end
        end
      end
    end
  end
  page
end
