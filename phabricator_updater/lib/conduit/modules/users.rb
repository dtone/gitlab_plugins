# frozen_string_literal: true

module Api
  module Conduit
    # module allows call operation with projects in Phabricator
    module Users
      # to see how to fill body read https://secure.phabricator.com/conduit/method/user.search
      def user_search(hashmap_query)
        call('/user.search', hashmap_query)
      end
    end
  end
end
