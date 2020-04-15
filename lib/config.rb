# frozen_string_literal: true

require 'gitlab'
require 'dotenv'

# common libs
require_relative 'logger/logger'
require_relative 'gitlab_file_storage'
# plugins
require_relative '../phabricator_updater/phabricator_updater'

module DT1
  # class to load and hold configuration for gitlab plugins in DT1
  class Config
    # this allows convert all Class attributes to hash without active record
    class Hashable
      def to_h
        instance_variables.each_with_object({}) do |var, hash_map|
          # var[1..-1].to_sym is to exclude @ in var name
          hash_map[var[1..-1].to_sym] = instance_variable_get(var)
        end
      end
    end

    @conduit = Class.new(Hashable) do
      attr_accessor :endpoint, :phabricator_url, :private_token, :ssh_phid,
                    :space_phid
    end.new
    @events = {}
    @gitlab = Class.new(Hashable) do
      attr_accessor :access_token, :endpoint, :private_token, :ssh_domain, :url,
                    :projects
    end.new
    @logger = Class.new(Hashable) do
      attr_accessor :formatter, :log_level, :outputter, :progname
    end.new
    @notifiers = []

    class << self
      attr_accessor :conduit, :events, :gitlab, :logger, :notifiers

      def load
        environment = ENV['ENVIRONMENT']
        raise 'Environment is not set' unless environment

        ::Dotenv.load(File.join(File.join(__dir__, '..', "#{environment}.env")))

        config_path = File.join(__dir__, '../config', environment)
        unless File.exist?("#{config_path}.rb")
          raise "Config file does not exists: #{config_path}"
        end

        require_relative config_path
      end

      def setup(&block)
        instance_eval(&block)

        ::Gitlab.endpoint = @gitlab.endpoint
        ::Gitlab.private_token = @gitlab.private_token

        ::Api::Conduit.endpoint = @conduit.endpoint
        ::Api::Conduit.private_token = @conduit.private_token
        ::Api::Conduit.phabricator_url = @conduit.phabricator_url
        ::Api::Conduit.space_phid = @conduit.space_phid
        ::Api::Conduit.gitlab_private_token = ::Gitlab.private_token
        ::PhabricatorUpdater::Config.gitlab = @gitlab
        ::PhabricatorUpdater::Config.conduit = @conduit

        ::DT1::Logger.setup(**@logger.to_h)
        ::Api::Conduit::Logger.logger = ::DT1::Logger
      end
    end
  end
end
