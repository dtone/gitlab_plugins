# frozen_string_literal: true

module Api
  module Conduit
    # class hold common's methods
    class Utils
      class << self
        def make_slug(string)
          string.downcase.gsub(/\s/, '_').delete(':')
        end

        def slug_from_name(name)
          make_slug(name)
        end

        def project_description(gitlab_link, diffusion_link, name)
          "[[ #{gitlab_link} | GitLab #{name} ]]\n\
[[ #{diffusion_link} | Diffusion #{name} ]]"
        end

        def phabricator_link(path)
          "#{Api::Conduit.phabricator_url}/#{path}"
        end

        def gitlab_link(path_with_namespace)
          "#{DT1::Config.gitlab.url}/#{path_with_namespace}"
        end
      end
    end
  end
end
