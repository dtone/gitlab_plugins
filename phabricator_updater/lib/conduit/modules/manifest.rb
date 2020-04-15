# frozen_string_literal: true

module Api
  module Conduit
    # module allows call operation with projects in Phabricator
    module Manifest
      # to see how to fill body read https://secure.phabricator.com/conduit/method/maniphest.search
      def maniphest_search(hashmap_query)
        call('/maniphest.search', hashmap_query)
      end
    end
  end
end
