# frozen_string_literal: true

require "spec_helper"

describe "Storing the Keycloak sub on the identity", type: :request do
  let(:organization) { create(:organization) }
  let(:nickname) { "jdoe" }
  let(:email) { "jdoe@example.org" }
  let(:sub) { "4f1c1a2e-0000-4000-8000-000000000001" }
  let(:claims) { { sub: sub, preferred_username: nickname, email: email, name: "John Doe" }.compact }

  # Build the auth hash with the REAL strategy (uid/info/extra blocks incl. the
  # engine's overrides), only stubbing the token/userinfo fetch.
  let(:auth_hash) do
    strategy = OmniAuth::Strategies::KeycloakOpenId.new(nil, "client", "secret",
                                                        client_options: { site: "https://kc.example.org", realm: "r" })
    allow(strategy).to receive(:raw_info).and_return(JSON::JWT.new(claims))
    allow(strategy).to receive(:access_token).and_return(OAuth2::AccessToken.new(strategy.client, "t"))
    strategy.auth_hash
  end

  before do
    organization.omniauth_settings = {
      omniauth_settings_keycloakopenid_enabled: true,
      omniauth_settings_keycloakopenid_client_id: "client",
      omniauth_settings_keycloakopenid_client_secret: "secret",
      omniauth_settings_keycloakopenid_site: "https://kc.example.org",
      omniauth_settings_keycloakopenid_realm: "r"
    }.transform_values { |v| Decidim::OmniauthProvider.value_defined?(v) ? Decidim::AttributeEncryptor.encrypt(v) : v }
    organization.save!
    host! organization.host
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:keycloakopenid] = auth_hash
  end

  after do
    OmniAuth.config.mock_auth.delete(:keycloakopenid)
    OmniAuth.config.test_mode = false
  end

  def callback!
    post "/users/auth/keycloakopenid/callback"
  end

  context "with an existing user and identity" do
    let!(:user) { create(:user, :confirmed, organization: organization, email: email) }
    let!(:identity) { create(:identity, user: user, provider: "keycloakopenid", uid: nickname, keycloak_sub: stored_sub) }
    let(:stored_sub) { nil }

    it "keeps preferred_username as uid" do
      expect(auth_hash["uid"]).to eq(nickname)
    end

    it "sets the sub when empty" do
      callback!
      expect(identity.reload.keycloak_sub).to eq(sub)
      expect(identity.uid).to eq(nickname)
      expect(Decidim::Keycloak.sub_for(user, organization)).to eq(sub)
    end

    context "when the same sub is stored" do
      let(:stored_sub) { sub }

      it "does nothing" do
        expect { callback! }.not_to(change { identity.reload.updated_at })
        expect(identity.reload.keycloak_sub).to eq(sub)
      end
    end

    context "when a different sub is stored" do
      let(:stored_sub) { "other-sub" }

      it "does not overwrite and logs a warning" do
        allow(Rails.logger).to receive(:warn)
        callback!
        expect(identity.reload.keycloak_sub).to eq("other-sub")
        expect(Rails.logger).to have_received(:warn).with(/not overwriting/)
      end
    end

    context "when the sub belongs to another identity" do
      before do
        create(:identity, user: create(:user, :confirmed, organization: organization),
                          provider: "keycloakopenid", uid: "someone", keycloak_sub: sub)
      end

      it "does not set it and logs a warning" do
        allow(Rails.logger).to receive(:warn)
        callback!
        expect(identity.reload.keycloak_sub).to be_nil
        expect(Rails.logger).to have_received(:warn).with(/already belongs to another identity/)
      end
    end

    context "when the token has no sub" do
      let(:claims) { { preferred_username: nickname, email: email, name: "John Doe" } }

      it "does nothing" do
        callback!
        expect(identity.reload.keycloak_sub).to be_nil
      end
    end
  end

  context "when the session's verified sub was set for a different organization" do
    let(:other_organization) { create(:organization) }
    let!(:other_identity) do
      create(:identity, user: create(:user, :confirmed, organization: other_organization),
                        provider: "keycloakopenid", uid: nickname, keycloak_sub: nil)
    end

    # No identity for `nickname` exists yet in `organization`, so the first
    # callback goes through the (irrelevant here) new-user/ToS path; stub its
    # rendering exactly like the "new user" context below, so the request
    # completes and the after_action still runs without depending on views.
    before do
      allow_any_instance_of(Decidim::Devise::OmniauthRegistrationsController) # rubocop:disable RSpec/AnyInstance
        .to receive(:render).and_wrap_original do |original, *args, **kwargs|
          args.first == :new_tos_fields ? original.receiver.head(:ok) : original.call(*args, **kwargs)
        end
    end

    it "is not applied to a same-uid identity of another organization" do
      # No identity with this uid exists yet in `organization`, so the store
      # step no-ops and leaves the verified sub sitting in the (signed) session.
      callback!
      expect(Decidim::Identity.exists?(organization: organization, uid: nickname)).to be(false)

      # A session cookie is scoped to the whole app, not to one organization,
      # so it can be replayed against another one. Any action on the omniauth
      # registrations controller runs the after_action that would consume it;
      # use an unrelated, harmless registration to reach it without raising.
      host! other_organization.host
      post "/omniauth_registrations.user", params: {
        user: { provider: "keycloakopenid", uid: "harmless", email: "harmless@example.org",
                name: "Harmless Person", nickname: "harmless", tos_agreement: "1",
                oauth_signature: Decidim::OmniauthRegistrationForm.create_signature("keycloakopenid", "harmless") }
      }

      expect(other_identity.reload.keycloak_sub).to be_nil
    end
  end

  context "with a new user that has to accept the ToS" do
    # The ToS form itself is irrelevant here; skip template rendering so the
    # spec does not depend on compiled frontend assets.
    before do
      allow_any_instance_of(Decidim::Devise::OmniauthRegistrationsController) # rubocop:disable RSpec/AnyInstance
        .to receive(:render).and_wrap_original do |original, *args, **kwargs|
          args.first == :new_tos_fields ? original.receiver.head(:ok) : original.call(*args, **kwargs)
        end
    end

    it "stores the verified sub, ignoring tampered form params" do
      callback!
      expect(Decidim::Identity.count).to eq(0)

      post "/omniauth_registrations.user", params: {
        user: { provider: "keycloakopenid", uid: nickname, email: email, name: "John Doe", nickname: nickname,
                tos_agreement: "1", oauth_signature: Decidim::OmniauthRegistrationForm.create_signature("keycloakopenid", nickname),
                raw_data: { extra: { raw_info: { sub: "forged" } } }.to_json }
      }
      identity = Decidim::Identity.find_by(provider: "keycloakopenid", uid: nickname)
      expect(identity).to be_present
      expect(identity.keycloak_sub).to eq(sub)
    end
  end
end
