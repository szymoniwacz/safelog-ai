# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::ClientResolver do
  describe ".current" do
    it "returns a fake client in test" do
      expect(described_class.current).to be_a(Ai::FakeClient)
    end
  end
end
