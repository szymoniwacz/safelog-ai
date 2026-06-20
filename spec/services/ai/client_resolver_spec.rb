# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::ClientResolver do
  describe ".current" do
    it "returns a fake client in test" do
      expect(described_class.current).to be_a(Ai::FakeClient)
    end

    it "returns an invalid client when E2E header mode is set" do
      Ai::E2eContext.client_mode = "invalid"

      expect(described_class.current).to be_a(Ai::InvalidClient)
    ensure
      Ai::E2eContext.reset
    end
  end

  describe ".fake_client_active?" do
    it "is false in test so the UI notice stays out of request specs" do
      expect(described_class.fake_client_active?).to be(false)
    end
  end
end
