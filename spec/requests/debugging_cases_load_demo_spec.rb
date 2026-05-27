# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Debugging case load demo", type: :request do
  let(:user) { create(:user, email: "demo-load@example.com") }

  describe "POST /debugging_cases/load_demo" do
    it "redirects guests to sign in" do
      post load_demo_debugging_cases_path

      expect(response).to redirect_to(new_user_session_path)
      expect(DebuggingCase.count).to eq(0)
    end

    it "creates a demo case for the signed-in user and redirects to show" do
      sign_in user

      expect {
        post load_demo_debugging_cases_path
      }.to change(DebuggingCase, :count).by(1)

      debugging_case = DebuggingCase.last
      expect(response).to redirect_to(debugging_case_path(debugging_case))
      expect(flash[:notice]).to eq("Demo case loaded.")
      expect(debugging_case.user).to eq(user)
      expect(debugging_case.title).to include("Checkout payment timeout")
      expect(debugging_case.log_sources.count).to eq(3)

      sanitized = debugging_case.log_sources.map(&:sanitized_content).join
      expect(sanitized).to include("[REQUEST_1]")
      expect(sanitized).not_to include(Demo::CaseFixture::DEMO_EMAIL)
      expect(sanitized).not_to include(Demo::CaseFixture::DEMO_TOKEN)
    end

    it "returns not found when the demo loader is unavailable" do
      sign_in user
      allow(Demo::LoadCase).to receive(:available?).and_return(false)

      expect {
        post load_demo_debugging_cases_path
      }.not_to change(DebuggingCase, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
