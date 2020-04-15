#!/usr/bin/env ruby
# frozen_string_literal: true

require 'socket'

begin
  event = STDIN.read
  s = TCPSocket.new('localhost', 2019)
  s.puts(event)
  s.close
rescue StandardError => e
  # GitLab logs only errors and no more
  # itnot sure if it can proceed also cause error
  raise "#{e.message}"\
  " Event: #{event}"\
  " Cause: #{e.backtrace}"
end
