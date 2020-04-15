# frozen_string_literal: true

require 'faraday'
require 'oj'

require_relative 'logger'
require_relative 'body_formatter'
require_relative 'modules/differential'
require_relative 'modules/diffusion'
require_relative 'modules/manifest'
require_relative 'modules/project'
require_relative 'modules/users'

module Api
  # namespace arround Api Conduit
  # allows use logger method to return logger
  module Conduit
    extend ::Api::Conduit::Differential
    extend ::Api::Conduit::Diffusion
    extend ::Api::Conduit::Logger
    extend ::Api::Conduit::Manifest
    extend ::Api::Conduit::Project
    extend ::Api::Conduit::Users

    class << self
      attr_writer :private_token, :endpoint, :phabricator_url
      attr_accessor :space_phid, :gitlab_private_token

      def private_token
        @private_token || ENV['CONDUIT_API_ACCESS_TOKEN']
      end

      def endpoint
        @endpoint || ENV['CONDUIT_API_ENDPOINT']
      end

      def phabricator_url
        @phabricator_url || ENV['PHABRICATOR_URL']
      end

      def call(url_path, hashmap_query = nil)
        response = faraday_call(url_path, hashmap_query)
        response = Oj.load(response.body)
        unless response['error_code']
          ret = yield(response) if block_given?
          return ret ||
                 response['result']['data'] ||
                 response['result']['object'] ||
                 response['result']
        end

        # TODO
        # place own error with better description not only error from API
        raise(StandardError, Oj.dump(response))
      end

      private

      def faraday_call(url_path, query = nil)
        called_request = nil
        response = Faraday.new.post("#{endpoint}#{url_path}") do |request|
          request.params['api.token'] = private_token
          request.headers['Content-Type'] = 'application/x-www-form-urlencoded'
          request.body = BodyFormatter.to_conduit(query) if query
          yield(request) if block_given?
          called_request = request
        end
        Api::Conduit::Logger.debug(message: 'Conduit#call',
                                   request: called_request.to_json,
                                   response: { body: response.body.to_json,
                                               http_code: response.status,
                                               headers: response.headers })
        return response if response.success?

        raise(StandardError, "#{response.status}: #{response.body}")
      end
    end
  end
end
