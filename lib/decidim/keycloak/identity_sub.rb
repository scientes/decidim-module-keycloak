# frozen_string_literal: true

module Decidim
  module Keycloak
    # Persists the Keycloak `sub` claim on the matching Decidim::Identity.
    module IdentitySub
      PROVIDER = "keycloakopenid"

      module_function

      # Extracts the sub from a verified OmniAuth auth hash. `raw_info` is the
      # userinfo/ID token claims the strategy fetched itself; the id_token is
      # only decoded as a fallback and only ever from the verified auth hash.
      def sub_from_auth(auth)
        return if auth.blank?

        sub = auth.dig("extra", "raw_info", "sub").presence
        sub ||= auth.dig("extra", "sub").presence
        sub ||= sub_from_id_token(auth.dig("extra", "id_token") || auth.dig("credentials", "id_token"))
        sub&.to_s
      end

      def sub_from_id_token(token)
        return if token.blank?

        JSON::JWT.decode(token, :skip_verification)["sub"].presence
      rescue StandardError
        nil
      end

      # empty -> set; same -> no-op; different -> keep + warn;
      # already used by another identity -> keep + warn.
      def apply(identity, sub)
        return false if identity.nil? || sub.blank?
        return false if identity.keycloak_sub == sub

        if identity.keycloak_sub.present?
          Rails.logger.warn("[decidim-keycloak] Identity #{identity.id} has keycloak_sub #{identity.keycloak_sub.inspect}, " \
                            "login presented #{sub.inspect}; not overwriting")
          return false
        end

        conflict = Decidim::Identity.where(decidim_organization_id: identity.decidim_organization_id,
                                           provider: identity.provider, keycloak_sub: sub)
                                    .where.not(id: identity.id).exists?
        if conflict
          Rails.logger.warn("[decidim-keycloak] keycloak_sub #{sub.inspect} already belongs to another identity; " \
                            "not setting it on identity #{identity.id}")
          return false
        end

        identity.update_column(:keycloak_sub, sub) # rubocop:disable Rails/SkipsModelValidations
        true
      rescue ActiveRecord::RecordNotUnique
        Rails.logger.warn("[decidim-keycloak] keycloak_sub #{sub.inspect} already belongs to another identity (race)")
        false
      end
    end
  end
end
