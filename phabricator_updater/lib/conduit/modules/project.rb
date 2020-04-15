# frozen_string_literal: true

module Api
  module Conduit
    # module allows call operation with projects in Phabricator
    module Project
      # to see how to fill body read https://secure.phabricator.com/conduit/method/project.edit/
      # e.g response
      # {
      #   "result": {
      #     "object": {
      #       "id": 15,
      #       "phid": "PHID-PROJ-j3vehfach4dxe6gw5h3p"
      #     },
      #     "transactions": []
      #   },
      #   "error_code": null,
      #   "error_info": null
      # }
      def project_edit(hashmap_query)
        call('/project.edit', hashmap_query)
      end

      # to see how to fill body read https://secure.phabricator.com/conduit/method/project.search/
      def project_search(hashmap_query)
        call('/project.search', hashmap_query)
      end
    end
  end
end
