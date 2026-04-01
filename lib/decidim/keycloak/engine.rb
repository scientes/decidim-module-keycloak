# frozen_string_literal: true

require "omniauth/strategies/keycloak-openid"

module Decidim
  module Keycloak
    # This is the engine that runs on the public interface of keycloak.
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::Keycloak

      # Register the Keycloak provider with Decidim so it appears in
      # organization settings and is known to the Decidim admin UI.
      initializer "decidim_keycloak.register_provider" do
        Decidim.omniauth_providers[:keycloakopenid] = {
          enabled: ENV.fetch("OMNIAUTH_KEYCLOAK_ENABLED", "true") == "true",
          icon_path: "media/images/keycloak_logo.svg"
        }
      end

      # Add the OmniAuth middleware for Keycloak.
      # Reads per-organization config at request time, falling back to ENV.
      initializer "decidim_keycloak.middleware" do |app|
        next unless Decidim.omniauth_providers[:keycloakopenid]

        app.config.middleware.use OmniAuth::Builder do
          provider :keycloak_openid, setup: lambda { |env|
            request = Rack::Request.new(env)
            organization = Decidim::Organization.find_by(host: request.host)
            provider_config = organization&.enabled_omniauth_providers&.dig(:keycloakopenid) || {}

            env["omniauth.strategy"].options[:client_id] =
              provider_config[:client_id].presence || ENV["OMNIAUTH_KEYCLOAK_CLIENT_ID"]

            env["omniauth.strategy"].options[:client_secret] =
              provider_config[:client_secret].presence || ENV["OMNIAUTH_KEYCLOAK_CLIENT_SECRET"]

            site = provider_config[:site].presence || ENV["OMNIAUTH_KEYCLOAK_SITE"]
            realm = provider_config[:realm].presence || ENV["OMNIAUTH_KEYCLOAK_REALM"]
            base_url = provider_config[:base_url].presence || ENV["OMNIAUTH_KEYCLOAK_BASE_URL"]

            env["omniauth.strategy"].options[:client_options] = {
              site: site,
              realm: realm,
              base_url: base_url,
              redirect_uri: request.url.split("?").first + "/callback" # remove the language parameter from the callback url
            }.compact
          }
        end
      end

      config.to_prepare do
        class OmniAuth::Strategies::KeycloakOpenId
          uid { raw_info["preferred_username"] }

          info do
            {
              nickname: raw_info["preferred_username"],
              name: raw_info["name"],
              email: raw_info["email"]
            }
          end
        end
      end

      initializer "decidim_keycloak.webpacker.assets_path" do
        Decidim.register_assets_path File.expand_path("app/packs", root)
      end
    end
  end
end
