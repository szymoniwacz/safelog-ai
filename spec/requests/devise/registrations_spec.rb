# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Devise registrations", type: :request do
  describe "POST /users" do
    it "creates a user and ends signed in with access to the dashboard" do
      expect do
        post user_registration_path, params: {
          user: {
            email: "new@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end.to change(User, :count).by(1)

      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Signed in as new@example.com")
      expect(response.body).not_to include("password123")
    end

    it "does not create a user when params are invalid" do
      expect do
        post user_registration_path, params: {
          user: {
            email: "",
            password: "short",
            password_confirmation: "short"
          }
        }
      end.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).not_to include("password123")
    end
  end
end
