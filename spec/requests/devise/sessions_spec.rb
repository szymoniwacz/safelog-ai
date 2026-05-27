# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Devise sessions", type: :request do
  let(:user) { create(:user, email: "member@example.com", password: "password123") }

  describe "POST /users/sign_in" do
    it "signs in with valid credentials and redirects to the dashboard" do
      post user_session_path, params: {
        user: {
          email: user.email,
          password: "password123"
        }
      }

      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Signed in as member@example.com")
      expect(response.body).not_to include("password123")
    end

    it "does not sign in with invalid credentials" do
      post user_session_path, params: {
        user: {
          email: user.email,
          password: "wrong-password"
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).not_to include("wrong-password")
    end
  end

  describe "DELETE /users/sign_out" do
    it "signs out and blocks access to the dashboard" do
      sign_in user

      delete destroy_user_session_path

      follow_redirect!
      get root_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
