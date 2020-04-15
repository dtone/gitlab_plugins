# frozen_string_literal: true

require 'oj'

require_relative 'attachment_formatter'
require_relative 'message_formatter'
require_relative 'url_formatter'

# class to reports errors, warnings and info to Slack channel
class SlackNotifier
  INVITE_URL = 'https://%<workspace>s.slack.com/api/channels.invite'
  USER_LIST_URL = 'https://%<workspace>s.slack.com/api/users.list'

  def initialize(options = {})
    @allow_notify = options[:allow_notify]
    @invite = options[:invite]
    @channel = options[:channel]
    @mention = options[:mention]
    level = options[:mention_level] || :warn
    @mention_level = Logger.const_get(level.upcase)
    @oauth_access_token = options[:oauth_access_token]
    @webhook = options[:webhook]
    @workspace = options[:workspace]
  end

  def notify(reports)
    reports.each do |report|
      actions = UrlFormatter.format(report[:urls])
      attachments = [
        AttachmentFormatter.format(report, actions, mention?(report))
      ]
      message = MessageFormatter.format(report, attachments)

      invite(report) unless @invite
      send_message(message)
    end
  end

  def mention?(report)
    if @mention
      @mention_level <= Logger.const_get(
        report.fetch(:type, :info).upcase
      )
    else
      false
    end
  end

  def invite_url
    format(INVITE_URL, workspace: @workspace)
  end

  def user_list_url
    format(USER_LIST_URL, workspace: @workspace)
  end

  def invite(report)
    email = report.dig(:user, :email)
    return unless email

    if @allow_notify
      user_list = Oj.load(faraday_call(user_list_url, nil).body)
      person = user_list['members'].find do |m|
        m['profile']['email'] == email
      end

      Api::Conduit::Logger.debug(message: 'Person to invite',
                                 persion: { id: person&.dig('id'),
                                            email: email })

      if person
        faraday_call(invite_url, channel: @channel,
                                 user: person['id'])
      end
    else
      Api::Conduit::Logger.debug(message: __method__)
    end
  end

  def send_message(message)
    if @allow_notify
      faraday_call(@webhook, message)
    else
      Api::Conduit::Logger.debug(message: 'SlackNotifier#send_message',
                                 request: message.to_json)
    end
  end

  private

  def faraday_call(url, message)
    called_request = nil
    response = Faraday.new.post(url) do |request|
      headers(request)
      request.body = message.to_json if message
      yield(request) if block_given?
      called_request = request
    end
    Api::Conduit::Logger.debug(message: 'SlackNotifier#call',
                               request: called_request.to_json,
                               response: { body: response.body.to_json,
                                           http_code: response.status,
                                           headers: response.headers })
    response
  rescue StandardError => e
    Api::Conduit::Logger.error(exception: e,
                               message: 'Cannot do faraday call.')
    raise e
  end

  def headers(request)
    request.headers['Authorization'] = "Bearer #{@oauth_access_token}"
    request.headers['Content-type'] = 'application/json'
  end
end
