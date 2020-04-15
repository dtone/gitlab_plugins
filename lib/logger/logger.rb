# frozen_string_literal: true

require 'logger'
require_relative 'json_formatter'

module DT1
  # basic wrapper around Ruby logger
  # it logs primary to STDOUT
  module Logger
    module_function

    class << self
      def setup(outputter: STDOUT,
                formatter: DT1::Logger::JsonFormatter.new,
                log_level: ::Logger::INFO,
                progname:)
        @logger = ::Logger.new(outputter)
        @logger.level = log_level
        @logger.formatter = formatter
        @logger.progname = progname
      end
    end

    def log(severity, log_message)
      @logger ||= setup
      @logger.public_send(severity, log_message)
    end

    # allow call with severity witout method_missing
    %i[debug info warn error fatal].each do |severity|
      define_method(severity) do |log_message|
        log(severity, log_message)
      end
    end
  end
end
