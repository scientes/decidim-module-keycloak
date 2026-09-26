# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Keycloak
    describe IdentitySub do
      describe ".sub_from_auth" do
        let(:sub) { "4f1c1a2e-0000-4000-8000-000000000002" }

        it "returns nil for a blank auth hash" do
          expect(described_class.sub_from_auth(nil)).to be_nil
        end

        it "reads the sub from the verified extra.raw_info" do
          auth = { "extra" => { "raw_info" => { "sub" => sub } } }
          expect(described_class.sub_from_auth(auth)).to eq(sub)
        end

        it "returns nil when raw_info has no sub, even if extra.id_token carries one" do
          # The strategy's own (verified) userinfo has no sub, but an id_token
          # with a `sub` claim is present. There must be no fallback that
          # decodes it without verification: the method returns nil.
          id_token = JSON::JWT.new(sub: sub).to_s
          auth = { "extra" => { "raw_info" => {}, "id_token" => id_token } }

          expect(described_class.sub_from_auth(auth)).to be_nil
        end
      end

      describe ".apply" do
        let(:organization) { create(:organization) }
        let(:user) { create(:user, :confirmed, organization: organization) }
        let(:sub) { "4f1c1a2e-0000-4000-8000-000000000003" }
        let!(:identity) do
          create(:identity, user: user, provider: "keycloakopenid", uid: "jdoe", keycloak_sub: nil)
        end

        it "writes the sub atomically when the column is still empty" do
          expect(described_class.apply(identity, sub)).to be(true)
          expect(identity.keycloak_sub).to eq(sub)
          expect(identity.reload.keycloak_sub).to eq(sub)
        end

        it "does not apply when identity is nil or sub is blank" do
          expect(described_class.apply(nil, sub)).to be(false)
          expect(described_class.apply(identity, "")).to be(false)
          expect(described_class.apply(identity, nil)).to be(false)
        end

        context "when a concurrent request already stored a different sub" do
          let(:other_sub) { "4f1c1a2e-0000-4000-8000-000000000004" }

          before do
            # Simulate another login winning the race between this `identity`
            # being loaded (still nil in memory) and `apply` running its
            # conditional UPDATE: the DB row already holds a different sub.
            Decidim::Identity.where(id: identity.id).update_all(keycloak_sub: other_sub) # rubocop:disable Rails/SkipsModelValidations
          end

          it "does not overwrite the stored value and logs a warning" do
            expect(identity.keycloak_sub).to be_nil # stale in-memory copy

            allow(Rails.logger).to receive(:warn)
            expect(described_class.apply(identity, sub)).to be(false)

            expect(identity.reload.keycloak_sub).to eq(other_sub)
            expect(Rails.logger).to have_received(:warn).with(/not overwriting/)
          end
        end

        context "when a concurrent request already stored the very same sub" do
          before do
            Decidim::Identity.where(id: identity.id).update_all(keycloak_sub: sub) # rubocop:disable Rails/SkipsModelValidations
          end

          it "leaves the value untouched, without warning, and reports it did not write it" do
            expect(identity.keycloak_sub).to be_nil # stale in-memory copy

            allow(Rails.logger).to receive(:warn)
            expect(described_class.apply(identity, sub)).to be(false)

            expect(identity.reload.keycloak_sub).to eq(sub)
            expect(Rails.logger).not_to have_received(:warn)
          end
        end
      end
    end
  end
end
