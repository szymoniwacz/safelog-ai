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

    it "rejects mass-assignment of user_id, archived_at, and id on create" do
      other_user = create(:user, email: "other-#{SecureRandom.hex(4)}@example.com")
      sign_in user

      expect {
        post debugging_cases_path, params: submission_params.deep_merge(
          debugging_case: {
            user_id: other_user.id,
            archived_at: Time.current,
            id: 999
          }
        )
      }.to change(DebuggingCase, :count).by(1)

      created_case = DebuggingCase.last

      expect(response).to redirect_to(debugging_case_path(created_case))
      expect(created_case.user).to eq(user)
      expect(created_case.user_id).not_to eq(other_user.id)
      expect(created_case.archived_at).to be_nil
      expect(created_case).not_to be_archived
    end

    it "re-renders new with 422 when title is blank" do
      sign_in user

      post debugging_cases_path, params: submission_params.deep_merge(
        debugging_case: { title: "" }
      )

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("New debugging case")
      expect(response.body).to include("Title can&#39;t be blank")
      expect(response.body).to include('form-field--invalid')
      expect(response.body).to include('aria-invalid="true"')
    end

    it "re-renders new with 422 when source type is invalid" do
      sign_in user

      post debugging_cases_path, params: submission_params.deep_merge(
        debugging_case: {
          sources: [
            { source_type: "invalid_type", pasted_content: "session_id=sess-http-1" }
          ]
        }
      )

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("invalid source type")
      expect(response.body).to include("fieldset--invalid")
    end

    it "reports source 2 in the error when only the second slot has an invalid type" do
      sign_in user

      post debugging_cases_path, params: {
        debugging_case: {
          title: "Slot numbering case",
          sources: [
            { source_type: "rails_log", pasted_content: "" },
            { source_type: "invalid_type", pasted_content: "session_id=sess-slot-2" }
          ]
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("source 2 has an invalid source type")
      expect(response.body).not_to include("session_id=sess-slot-2")
    end

    it "preserves source type and name without re-rendering pasted content on validation failure" do
      sign_in user
      pasted_secret = "paste-#{SecureRandom.hex(4)}@secret.example"

      post debugging_cases_path, params: {
        debugging_case: {
          title: "Source metadata preserve case",
          sources: [
            {
              source_type: "invalid_type",
              name: "Rails",
              pasted_content: pasted_secret
            }
          ]
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('value="Rails"')
      expect(response.body).to match(/value="invalid_type"[^>]*selected|selected[^>]*value="invalid_type"/)
      expect(response.body).not_to include(pasted_secret)
    end

    it "preserves metadata fields on validation failure" do
      sign_in user

      post debugging_cases_path, params: {
        debugging_case: {
          title: "Metadata preserve case",
          description: "Reporter notes",
          customer_reference: "Ticket #999",
          environment: "staging",
          sources: [
            { source_type: "rails_log", pasted_content: "" }
          ]
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('value="Metadata preserve case"')
      expect(response.body).to include("Reporter notes")
      expect(response.body).to include('value="Ticket #999"')
      expect(response.body).to include('value="staging"')
    end

    it "does not re-render pasted content on validation failure" do
      sign_in user
      pasted_secret = "paste-#{SecureRandom.hex(4)}@secret.example"

      post debugging_cases_path, params: {
        debugging_case: {
          title: "Pasted content safety case",
          sources: [
            { source_type: "invalid_type", pasted_content: pasted_secret }
          ]
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).not_to include(pasted_secret)
      expect(response.body).to include('aria-invalid="true"')
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

    it "renders analyze loading UI for in-flight feedback" do
      sign_in user

      get debugging_case_path(debugging_case)

      expect(response.body).to include('id="analyze-case-form"')
      expect(response.body).to include('id="analyze-case-status"')
      expect(response.body).to include('class="spinner"')
      expect(response.body).to include("Analyzing case… correlation and AI may take a few seconds.")
      expect(response.body).to include('document.body.classList.add("is-analyzing")')
    end
  end
end
