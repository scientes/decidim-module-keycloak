# frozen_string_literal: true

require "omniauth/strategies/keycloak-openid"

module Decidim
  module Keycloak
    # This is the engine that runs on the public interface of keycloak.
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::Keycloak

      initializer "decidim.keycloak.middleware" do |app|
        # Check for environment variables (new method) or secrets.yml (backwards compatibility)
        has_env_config = ENV["DECIDIM_KEYCLOAK_CLIENT_ID"].present?
        has_secrets_config = Rails.application.secrets.dig(:omniauth, :keycloakopenid).present?
        
        next unless has_env_config || has_secrets_config

        app.config.middleware.use OmniAuth::Builder do
          provider :keycloak_openid, setup: lambda { |env|
            request = Rack::Request.new(env)
            organization = Decidim::Organization.find_by(host: request.host)
            config = organization.enabled_omniauth_providers[:keycloakopenid]
            
            # Use environment variables first (preferred), fall back to config/secrets
            env["omniauth.strategy"].options[:client_id] = ENV.fetch("DECIDIM_KEYCLOAK_CLIENT_ID", config[:client_id])
            env["omniauth.strategy"].options[:client_secret] = ENV.fetch("DECIDIM_KEYCLOAK_CLIENT_SECRET", config[:client_secret])
            
            site = ENV.fetch("DECIDIM_KEYCLOAK_SITE", config[:site])
            realm = ENV.fetch("DECIDIM_KEYCLOAK_REALM", config[:realm])
            base_url = ENV.fetch("DECIDIM_KEYCLOAK_BASE_URL", config[:base_url])
            
            env["omniauth.strategy"].options[:client_options] = { 
              site: site, 
              realm: realm, 
              base_url: base_url, 
              redirect_uri: request.url.split("?").first + "/callback" # remove the language parameter from the callback url
            }
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
