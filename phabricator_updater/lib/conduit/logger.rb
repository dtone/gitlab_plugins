# frozen_string_literal: true

require 'logger'

module Api
  module Conduit
    # module to allow paste any logger into Api::Conduit
    # and call just logger.info|debug|...
    module Logger
      module_function

      def logger=(logger)
        @logger = logger
      end

      def logger
        @logger ||= ::Logger.new('/dev/null')
      end

      %i[debug info warn error fatal].each do |severity|
        define_method(severity) do |log_message|
          logger.public_send(severity, log_message)
        end
      end
    end
  end
end
