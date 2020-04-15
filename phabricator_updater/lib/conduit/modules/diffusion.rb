# frozen_string_literal: true

module Api
  module Conduit
    # module allows call operation with projects in Phabricator
    module Diffusion
      # to see how to fill body read https://secure.phabricator.com/conduit/method/diffusion.repository.edit/
      def diffusion_repository_edit(hashmap_query)
        call('/diffusion.repository.edit', hashmap_query)
      end

      # to see how to fill body read https://secure.phabricator.com/conduit/method/diffusion.repository.search/
      def diffusion_repository_search(hashmap_query)
        call('/diffusion.repository.search', hashmap_query) do |raw_data|
          yield(raw_data) if block_given?
        end
      end

      # to see how to fill body read https://secure.phabricator.com/conduit/method/diffusion.uri.edit/
      def diffusion_uri_edit(hashmap_query)
        call('/diffusion.uri.edit', hashmap_query)
      end
    end
  end
end
