#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'oj'

DIRECTORY = '/tmp'

raw_event = STDIN.read

def file_name(event_name, index)
  format("#{event_name}%03d", index)
end

tmp_log = File.open(File.join(DIRECTORY, 'event_recorder.log'), 'a')
begin
  event = Oj.load(raw_event)
  event_name = event['event_name'] || event['event_type']
  index = Dir.glob(File.join(DIRECTORY, "#{event_name}*")).size
  File.open(File.join(DIRECTORY, file_name(event_name, index)), 'w') do |file|
    file.write(raw_event)
  end
rescue StandardError => e
  puts e
  tmp_log.write(Time.now)
  tmp_log.write(e)
  tmp_log.write("\n")
  tmp_log.write(e.backtrace)
end
