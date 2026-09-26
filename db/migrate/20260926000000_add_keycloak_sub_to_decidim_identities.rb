# frozen_string_literal: true

# Stores the Keycloak user id (the OIDC `sub` claim) next to the identity uid
# (which stays `preferred_username`), so other integrations such as
# Nextcloud user_oidc can map a Decidim user to its Keycloak account.
class AddKeycloakSubToDecidimIdentities < ActiveRecord::Migration[7.0]
  def change
    add_column :decidim_identities, :keycloak_sub, :string
    add_index :decidim_identities,
              [:decidim_organization_id, :provider, :keycloak_sub],
              unique: true,
              where: "keycloak_sub IS NOT NULL",
              name: "index_decidim_identities_on_org_provider_keycloak_sub"
  end
end
