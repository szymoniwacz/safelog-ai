# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::ClientResolver do
  describe ".current" do
    it "returns a fake client in test" do
      expect(described_class.current).to be_a(Ai::FakeClient)
    end
  end

  describe ".fake_client_active?" do
    it "is false in test so the UI notice stays out of request specs" do
      expect(described_class.fake_client_active?).to be(false)
    end
  end
end
