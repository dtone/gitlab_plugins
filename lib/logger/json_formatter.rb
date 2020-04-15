# frozen_string_literal: true

require 'logger'
require 'oj'

module DT1
  module Logger
    # because we store log in Elastic Search
    # and ES stores everything as JSON document
    # there is a log formatter to JSON
    class JsonFormatter < ::Logger::Formatter
      TIMESTAMP_FORMAT = '%Y-%m-%d %H:%M:%S.%s'

      # Logger::Formatter define interface-method :call
      def call(severity, datetime, _progname, log_message)
        basic_data = {
          timestamp: datetime.strftime(TIMESTAMP_FORMAT),
          log_level: severity,
          environment: ENV['ENVIRONMENT']
        }
        whole_message = if log_message.is_a?(Hash)
                          merge(log_message, basic_data)
                        else
                          basic_data[:message] = log_message.to_s
                          basic_data
                        end

        "#{Oj.dump(whole_message, circular: true)}\n"
      rescue StandardError => e
        puts e
        puts 'FATAL LOGGER FORMAT'
        puts whole_message.to_s
        # ignore raise
      end

      def merge(log_message, basic_data)
        whole_message = log_message.merge(basic_data)
        return whole_message unless whole_message[:exception].is_a?(Exception)

        format_exception!(whole_message)
        whole_message
      end

      # expand exception into hash map with all causes
      def format_exception!(whole_message)
        exception = whole_message[:exception]
        tmp_exc_d = exception_details = {}
        loop do
          tmp_exc_d[:message] = exception.message
          tmp_exc_d[:class] = exception.class.name
          tmp_exc_d[:stack_trace] = exception.backtrace.join("\n  ")

          break unless exception.cause

          tmp_exc_d[:cause] = {}
          exception = exception.cause
          tmp_exc_d = tmp_exc_d[:cause]
        end

        whole_message[:exception] = exception_details
      end
    end
  end
end
