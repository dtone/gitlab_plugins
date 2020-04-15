# frozen_string_literal: true

module Api
  module Conduit
    # module allows call operation with projects in Phabricator
    module Differential
      # to see how to fill body read https://secure.phabricator.com/conduit/method/differential.creatediff
      def create_diff(hashmap_query)
        call('/differential.creatediff', hashmap_query)
      end

      # to see how to fill body read https://secure.phabricator.com/conduit/method/differential.revision.edit
      def differential_revision_edit(hashmap_query)
        call('/differential.revision.edit', hashmap_query)
      end

      # to see how to fill body read https://secure.phabricator.com/conduit/method/differential.revision.search
      def differential_revision_search(hashmap_query)
        call('/differential.revision.search', hashmap_query)
      end
    end
  end
end
