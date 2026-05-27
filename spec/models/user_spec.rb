# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  describe "factory" do
    it "creates a valid persisted user" do
      user = create(:user)

      expect(user).to be_persisted
      expect(user.email).to match(/\Auser\d+@example\.com\z/)
      expect(user.valid_password?("password123")).to be(true)
    end
  end
end
