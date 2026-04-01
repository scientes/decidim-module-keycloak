# frozen_string_literal: true

require "rails/generators/base"

module Decidim
  module Keycloak
    module Generators
      # @deprecated This generator is for Decidim <= 0.30 which used config/secrets.yml.
      #   In Decidim >= 0.31, secrets.yml was removed. The engine now reads ENV
      #   variables directly (OMNIAUTH_KEYCLOAK_*) and registers the provider
      #   via Decidim.omniauth_providers automatically.
      class SecretsGenerator < Rails::Generators::Base
        desc "This generator modifies secrets file adding keycloakid to omniauth methods (DEPRECATED for Decidim >= 0.31)"
        def modify_secrets_file
          case Rails.env
          when "development"
            inject_into_file "development_app/config/secrets.yml", after: "icon: phone" do
              <<~YAML
                |
                |    keycloakopenid:
                |      enabled: true
                |      icon_path: media/images/keycloak_logo.svg
                |      client_id: <%= ENV["OMNIAUTH_KEYCLOAK_CLIENT_ID"] %>
                |      client_secret: <%= ENV["OMNIAUTH_KEYCLOAK_CLIENT_SECRET"] %>
                |      site: <%= ENV["OMNIAUTH_KEYCLOAK_SITE"] %>
                |      realm: <%= ENV["OMNIAUTH_KEYCLOAK_REALM"] %>
                |      base_url: <%= ENV["OMNIAUTH_KEYCLOAK_BASE_URL"] %>
              YAML
                .gsub(/^ *\|/, "").rstrip
            end
          when "test"
            inject_into_file "spec/decidim_dummy_app/config/secrets.yml", after: "app_secret: fake-facebook-app-secret" do
              <<~YAML
                |
                |    keycloakopenid:
                |      enabled: false
                |      icon_path: media/images/keycloak_logo.svg
                |      client_id: fake-keycloakopenid-client-id
                |      client_secret: fake-keycloakopenid-client-secret
                |      site: https://fake.keycloakopenid.site
                |      realm: fake-keycloakopenid-realm
                |      base_url: https://fake.keycloakopenid.site
              YAML
                .gsub(/^ *\|/, "").rstrip
            end
          end
        end
      end
    end
  end
end
