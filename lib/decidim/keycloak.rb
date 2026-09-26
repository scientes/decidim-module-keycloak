# frozen_string_literal: true

require "decidim/keycloak/engine"
require "decidim/keycloak/identity_sub"

module Decidim
  # This namespace holds the logic of the `Keycloak` component
  module Keycloak
    # Returns the Keycloak user id (`sub`) of the given user's Keycloak
    # identity in the organization, or nil if it is not known (yet).
    def self.sub_for(user, organization = user&.organization)
      return if user.nil? || organization.nil?

      Decidim::Identity.where(user: user, organization: organization, provider: IdentitySub::PROVIDER)
                       .where.not(keycloak_sub: nil)
                       .pick(:keycloak_sub)
    end
  end
end
