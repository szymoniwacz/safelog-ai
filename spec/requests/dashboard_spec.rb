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

    it "shows the load demo action when the demo loader is available" do
      sign_in user

      get root_path

      expect(response.body).to include("Load demo case")
    end

    it "hides the load demo action when the demo loader is unavailable" do
      sign_in user
      allow(Demo::LoadCase).to receive(:available?).and_return(false)

      get root_path

      expect(response.body).not_to include("Load demo case")
    end

    it "shows a reviewer callout when the demo loader is available in production" do
      sign_in user
      allow(Rails.env).to receive(:development?).and_return(false)
      allow(Rails.env).to receive(:test?).and_return(false)
      allow(Rails.env).to receive(:production?).and_return(true)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("SAFELOG_ENABLE_DEMO_LOADER").and_return("true")

      get root_path

      expect(response.body).to include("Load demo case")
      expect(response.body).to include("reviewer convenience only")
    end

    it "shows a demo AI notice when the fake client is active outside test" do
      sign_in user
      allow(Ai::ClientResolver).to receive(:fake_client_active?).and_return(true)

      get root_path

      expect(response.body).to include("sample AI output")
      expect(response.body).to include("OPENAI_API_KEY")
    end
  end
end
