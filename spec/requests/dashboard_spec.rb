# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user, email: "dashboard@example.com") }

  describe "GET /" do
    it "redirects guests to sign in" do
      get root_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows the signed-in dashboard for authenticated users" do
      sign_in user

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Signed in as dashboard@example.com")
    end
  end
end
