# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Debugging cases", type: :request do
  let(:user) { create(:user, email: "cases@example.com") }

  describe "GET /debugging_cases/new" do
    it "redirects guests to sign in" do
      get new_debugging_case_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "returns success for signed-in users" do
      sign_in user

      get new_debugging_case_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("New debugging case")
    end
  end

  describe "POST /debugging_cases" do
    let(:secret_email) { "leak-#{SecureRandom.hex(4)}@secret.example" }

    def submission_params
      {
        debugging_case: {
          title: "Checkout failure",
          description: "Payment step hangs",
          customer_reference: "Ticket #12345",
          environment: "production",
          sources: [
            {
              source_type: "rails_log",
              name: "Rails",
              pasted_content: "User login failed for #{secret_email}"
            }
          ]
        }
      }
    end

    it "redirects guests to sign in" do
      post debugging_cases_path, params: submission_params

      expect(response).to redirect_to(new_user_session_path)
    end

    it "creates a case and redirects to show without exposing raw secrets" do
      sign_in user

      post debugging_cases_path, params: submission_params

      expect(response).to redirect_to(debugging_case_path(DebuggingCase.last))

      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("[EMAIL_1]")
      expect(response.body).not_to include(secret_email)
    end
  end

  describe "GET /debugging_cases/:id" do
    let!(:debugging_case) do
      result = Intake::ProcessCaseSubmission.call(
        user: user,
        submission: Intake::CaseSubmission.new(
          title: "Existing case",
          sources: [
            { source_type: "rails_log", pasted_content: "request_id=req-show-123" }
          ]
        )
      )
      result.debugging_case
    end

    it "redirects guests to sign in" do
      get debugging_case_path(debugging_case)

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows sanitized case detail for the owner" do
      sign_in user

      get debugging_case_path(debugging_case)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Existing case")
      expect(response.body).to include("[REQUEST_1]")
      expect(response.body).not_to include("req-show-123")
    end

    it "shows a demo AI notice when the fake client is active outside test" do
      sign_in user
      allow(Ai::ClientResolver).to receive(:fake_client_active?).and_return(true)

      get debugging_case_path(debugging_case)

      expect(response.body).to include("Demo AI client active")
    end
  end
end
