# frozen_string_literal: true

module Decidim
  module Keycloak
    # Included into Decidim::Devise::OmniauthRegistrationsController.
    #
    # Decidim routes the OmniAuth callbacks themselves to this controller
    # (Devise mapping `omniauth_callbacks: "decidim/devise/omniauth_registrations"`,
    # callback -> #action_missing -> #create), so the before_action below sees
    # the verified auth hash on the initial callback.
    #
    # Security: the sub is only ever taken from `request.env["omniauth.auth"]`,
    # which OmniAuth builds in the callback phase from data the strategy
    # fetched and verified itself (code exchange, JWKS). We deliberately do NOT use the
    # `raw_data` of Decidim's `decidim.user.omniauth_*` events: on the second
    # registration step (ToS form) that data comes from unsigned form params.
    # For that case the verified uid/sub pair is kept in the (signed and
    # encrypted) Rails session and applied once the identity with exactly that
    # uid exists.
    module StoreSubOnLogin
      extend ActiveSupport::Concern

      SESSION_KEY = "decidim_keycloak.verified_sub"

      included do
        before_action :decidim_keycloak_remember_verified_sub
        after_action :decidim_keycloak_store_sub
      end

      private

      def decidim_keycloak_remember_verified_sub
        auth = request.env["omniauth.auth"]
        return unless auth && auth["provider"].to_s == IdentitySub::PROVIDER

        sub = IdentitySub.sub_from_auth(auth)
        session.delete(SESSION_KEY)
        return unless sub.present? && auth["uid"].present? && current_organization

        # Bound to the organization of the callback: the session cookie can be
        # reused across organizations, and an abandoned registration in one
        # must never assign its sub to an identity with the same uid in another.
        session[SESSION_KEY] = { "organization_id" => current_organization.id, "uid" => auth["uid"].to_s, "sub" => sub }
      end

      def decidim_keycloak_store_sub
        verified = session[SESSION_KEY]
        return unless verified.is_a?(Hash) && current_organization
        return unless verified["organization_id"] == current_organization.id

        identity = Decidim::Identity.find_by(organization: current_organization,
                                             provider: IdentitySub::PROVIDER,
                                             uid: verified["uid"])
        return unless identity

        IdentitySub.apply(identity, verified["sub"])
        session.delete(SESSION_KEY)
      rescue StandardError => e
        Rails.logger.warn("[decidim-keycloak] Could not store keycloak_sub: #{e.class}: #{e.message}")
      end
    end
  end
end
