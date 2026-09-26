# frozen_string_literal: true

require "spec_helper"

describe "keycloak_sub migration" do
  it "is exposed by the engine (installable via decidim_keycloak:install:migrations)" do
    files = Decidim::Keycloak::Engine.paths["db/migrate"].existent.flat_map { |dir| Dir[File.join(dir, "*.rb")] }
    expect(files.map { |f| File.basename(f) }).to include(a_string_matching(/add_keycloak_sub_to_decidim_identities/))
    expect(Decidim::Keycloak::Engine.railtie_name).to eq("decidim_keycloak")
  end

  it "is packaged in the gem" do
    spec = Gem::Specification.load(File.expand_path("../../decidim-keycloak.gemspec", __dir__))
    expect(spec.files).to include(a_string_matching(%r{\Adb/migrate/.*add_keycloak_sub_to_decidim_identities}))
  end

  it "has been applied to the dummy app" do
    expect(Decidim::Identity.column_names).to include("keycloak_sub")
    index = ActiveRecord::Base.connection.indexes(:decidim_identities).find { |i| i.columns.include?("keycloak_sub") }
    expect(index).to have_attributes(unique: true, columns: %w(decidim_organization_id provider keycloak_sub))
    expect(index.where).to include("keycloak_sub IS NOT NULL")
  end
end
