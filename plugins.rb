# frozen_string_literal: true

require 'json'
require 'oj'
require 'socket'

require_relative 'lib/gitlab_file_storage'
require_relative 'lib/config'

DT1::Config.load

# Make listeners process the events, gather their output
def process_events(listeners, event)
  # every listener can return hash with keys for
  # notifiers to report what is done
  # see README.md
  # nil values are skipped
  attachs = catch(:error) do
    listeners.map do |listener|
      listener.notify(event)
    end
  end
  # it cannot use Arrray(hash) because hash is transformed
  # to [key, value] arrays
  # Array({:a => "a", :b => "b"}) #=> [[:a, "a"], [:b, "b"]]
  DT1::Logger.debug(message: 'Slack notification from listeners.',
                    slack: { notifications: attachs.to_json })
  [attachs.compact].compact.flatten
rescue StandardError => e
  DT1::Logger.error(message: 'Processing GitLab event failed',
                    event: { raw: event.to_json, name: event['event_name'] },
                    exception: e,
                    listeners: listeners.to_s)
  raise
end

# Send the outputs from the listeners to all notifiers
def notify_all(attachs)
  DT1::Config.notifiers.each do |notifier|
    notifier.notify(Array(attachs)) unless attachs.empty?
  rescue StandardError => e
    DT1::Logger.error(message: 'Notify failed',
                      notifier: { name: notifier.class.name },
                      exception: e)
  end
end

# Parse incoming GitLab data and find corresponding listeners
def process_client_data(client_data)
  event = Oj.load(client_data.strip)
  event_name = event['event_name'] || event['event_type']
  unless DT1::Config.events[event_name]
    DT1::Logger.debug(
      message: 'Skipping event, missing configuration for this event',
      event: { name: event_name, raw: client_data }
    )
    return
  end

  DT1::Config.events[event_name].each do |listeners|
    attachs = process_events(Array(listeners), event)
    notify_all(attachs)
  end
rescue StandardError => e
  DT1::Logger.fatal(message: 'Processing GitLab event failed',
                    event: { name: event_name, raw: client_data },
                    exception: e)
end

socket_port = 2019

ARGV.each_slice(2) do |cmd, value|
  case cmd
  when '-p', '--port'
    socket_port = value
  end
end

# Start listening on a socket for data coming from GitLab
# TODO: use fibers like here or some gem
# https://www.codeotaku.com/journal/2018-11/fibers-are-the-right-solution/index
server = TCPServer.open(socket_port)
loop do # Servers run forever
  # when server accepts client a new thread is created
  Thread.start(server.accept) do |client|
    # event should be on one line
    process_client_data(client.gets)
    client.close # Disconnect from the client
  end
end
