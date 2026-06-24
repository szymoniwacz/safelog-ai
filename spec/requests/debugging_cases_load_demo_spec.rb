# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Debugging case load demo", type: :request do
  let(:user) { create(:user, email: "demo-load@example.com") }

  describe "POST /debugging_cases/load_demo" do
    it "redirects guests to sign in" do
      expect {
        post load_demo_debugging_cases_path
      }.not_to change(DebuggingCase, :count)

      expect(response).to redirect_to(new_user_session_path)
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

    it "returns not found in production when SAFELOG_ENABLE_DEMO_LOADER is unset" do
      sign_in user
      allow(Rails.env).to receive(:development?).and_return(false)
      allow(Rails.env).to receive(:test?).and_return(false)
      allow(Rails.env).to receive(:production?).and_return(true)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("SAFELOG_ENABLE_DEMO_LOADER").and_return(nil)

      expect {
        post load_demo_debugging_cases_path
      }.not_to change(DebuggingCase, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "creates a demo case in production when SAFELOG_ENABLE_DEMO_LOADER is set" do
      sign_in user
      allow(Rails.env).to receive(:development?).and_return(false)
      allow(Rails.env).to receive(:test?).and_return(false)
      allow(Rails.env).to receive(:production?).and_return(true)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("SAFELOG_ENABLE_DEMO_LOADER").and_return("true")

      expect {
        post load_demo_debugging_cases_path
      }.to change(DebuggingCase, :count).by(1)

      expect(response).to redirect_to(debugging_case_path(DebuggingCase.last))
    end

    it "redirects with an alert when demo loading fails" do
      sign_in user
      failure = Intake::ProcessCaseSubmission::Result.new(
        debugging_case: nil,
        errors: [ "Demo fixture invalid" ]
      )
      allow(Demo::LoadCase).to receive(:call).and_return(failure)

      expect {
        post load_demo_debugging_cases_path
      }.not_to change(DebuggingCase, :count)

      expect(response).to redirect_to(debugging_cases_path)
      expect(flash[:alert]).to eq("Could not load demo case.")
    end
  end
end
