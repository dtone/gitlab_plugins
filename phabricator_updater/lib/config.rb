# frozen_string_literal: true

module PhabricatorUpdater
  # not nice class for hold configuration
  # it should be inherited
  class Config
    class << self
      attr_accessor :conduit, :gitlab
    end
  end
end
