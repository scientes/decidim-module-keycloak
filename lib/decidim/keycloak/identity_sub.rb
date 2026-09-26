# frozen_string_literal: true

module Decidim
  module Keycloak
    # Persists the Keycloak `sub` claim on the matching Decidim::Identity.
    module IdentitySub
      PROVIDER = "keycloakopenid"

      module_function

      # Extracts the sub from a verified OmniAuth auth hash. Only
      # `extra.raw_info` is used: the strategy builds it by decoding the access
      # token against the realm's JWKS, so its signature has been checked.
      # There is deliberately no fallback that decodes a token without
      # verification.
      def sub_from_auth(auth)
        return if auth.blank?

        auth.dig("extra", "raw_info", "sub").presence&.to_s
      end

      # empty -> set; same -> no-op; different -> keep + warn;
      # already used by another identity -> keep + warn.
      # The write is a conditional UPDATE (only while the column is still
      # NULL), so two concurrent logins can never overwrite each other.
      def apply(identity, sub)
        return false if identity.nil? || sub.blank?
        return false if identity.keycloak_sub == sub
        return warn_different(identity, sub) if identity.keycloak_sub.present?

        conflict = Decidim::Identity.where(decidim_organization_id: identity.decidim_organization_id,
                                           provider: identity.provider, keycloak_sub: sub)
                                    .where.not(id: identity.id).exists?
        if conflict
          Rails.logger.warn("[decidim-keycloak] keycloak_sub #{sub.inspect} already belongs to another identity; " \
                            "not setting it on identity #{identity.id}")
          return false
        end

        written = Decidim::Identity.where(id: identity.id, keycloak_sub: nil)
                                   .update_all(keycloak_sub: sub) # rubocop:disable Rails/SkipsModelValidations
        identity.reload
        return true if written == 1
        return false if identity.keycloak_sub == sub # a concurrent login stored the same value

        warn_different(identity, sub)
      rescue ActiveRecord::RecordNotUnique
        Rails.logger.warn("[decidim-keycloak] keycloak_sub #{sub.inspect} already belongs to another identity (race)")
        false
      end

      def warn_different(identity, sub)
        Rails.logger.warn("[decidim-keycloak] Identity #{identity.id} has keycloak_sub #{identity.keycloak_sub.inspect}, " \
                          "login presented #{sub.inspect}; not overwriting")
        false
      end
    end
  end
end
