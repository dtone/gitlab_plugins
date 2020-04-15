# frozen_string_literal: true

# this script loads all merge requests
# and checks where ticket id is missing
# (branch, title or descripion)
# and creates CSV files with statistics

require 'gitlab'
require 'json'
require 'pp'
require 'csv'
require 'date'

REGEXP_TASK_ID = /(?<=T)(\d+)/i.freeze

::Gitlab.endpoint = ENV['GITLAB_API_ENDPOINT'] # e.g. 'http://127.0.0.1:80/api/v4'
::Gitlab.private_token = ENV['GITLAB_API_PRIVATE_TOKEN']

def browse_pages(group_page_size = 50, group_page = 0)
  loop do
    page = yield(group_page_size, group_page)

    break page.size < group_page_size
  end
end

chart_data = {}

browse_pages(50, 0) do |g_page_size, g_page|
  g_page = Gitlab.groups(per_page: g_page_size, page: g_page)
  g_page.each do |group|
    Gitlab.group_projects(group.id,
                          per_page: 50).each_page do |projects|
      projects.each do |project|
        Gitlab.merge_requests(project.id).each_page do |merge_request_page|
          merge_request_page.each do |merge_request|
            date = Time.parse(merge_request.created_at).to_date.to_s
            chart_data[project.path] ||= {}
            chart_data[project.path][date] ||= Hash.new(0)
            branch = merge_request.source_branch[REGEXP_TASK_ID]
            title = merge_request.title[REGEXP_TASK_ID]
            description = merge_request.description.to_s[REGEXP_TASK_ID]

            if branch || title || description
              chart_data[project.path][date][:ID] += 1
            else
              chart_data[project.path][date][:NoID] += 1
            end

            chart_data[project.path][date][:branch] += 1 if branch
            chart_data[project.path][date][:title] += 1 if title
            chart_data[project.path][date][:description] += 1 if description

            chart_data[project.path][date][:mrs] += 1
          end
        end
      end
    end
  end
  g_page
end

CSV.open('merge_request_chart.csv', 'w') do |csv|
  csv << %w[date all ID NoID branch title description]
  chart_data.each do |project, data|
    CSV.open("merge_request_chart_#{project}.csv", 'w') do |p_csv|
      p_csv << %w[date all ID NoID branch title description]
      data.each do |date, values|
        row = [
          date,
          values[:mrs],
          values[:ID],
          values[:NoID],
          values[:branch],
          values[:title],
          values[:description]
        ]
        p_csv << row
        csv << row
      end
    end
  end
end
