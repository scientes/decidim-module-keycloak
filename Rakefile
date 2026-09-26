# frozen_string_literal: true

require "decidim/dev/common_rake"
require "decidim/keycloak/generators/secrets_generator"

desc "Generates a dummy app for testing"
task test_app: "decidim:generate_external_test_app" do
  ENV["RAILS_ENV"] = "test"
  Decidim::Keycloak::Generators::SecretsGenerator.start
  Dir.chdir("spec/decidim_dummy_app") do
    system("bundle exec rake decidim_keycloak:install:migrations", exception: true)
    system("bundle exec rake db:migrate", exception: true)
  end
end

desc "Generates a development app."
task development_app: "decidim:generate_external_development_app" do
  Decidim::Keycloak::Generators::SecretsGenerator.start
end
