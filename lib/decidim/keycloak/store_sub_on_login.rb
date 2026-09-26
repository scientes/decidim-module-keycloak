# frozen_string_literal: true

module Decidim
  module Keycloak
    # Included into Decidim::Devise::OmniauthRegistrationsController.
    #
    # Security: the sub is only ever taken from `request.env["omniauth.auth"]`,
    # which OmniAuth builds in the callback phase from data the strategy
    # fetched itself (code exchange + userinfo). We deliberately do NOT use the
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
        session[SESSION_KEY] = { "uid" => auth["uid"].to_s, "sub" => sub } if sub.present? && auth["uid"].present?
      end

      def decidim_keycloak_store_sub
        verified = session[SESSION_KEY]
        return unless verified.is_a?(Hash) && current_organization

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
