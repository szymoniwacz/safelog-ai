# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Debugging case update", type: :request do
  let(:owner) { create(:user, email: "update@example.com") }
  let(:other_user) { create(:user, email: "other-update@example.com") }

  let!(:debugging_case) do
    Intake::ProcessCaseSubmission.call(
      user: owner,
      submission: Intake::CaseSubmission.new(
        title: "Original title",
        description: "Original description",
        customer_reference: "Ticket #1",
        environment: "staging",
        sources: [ { source_type: "rails_log", pasted_content: "request_id=req-update-1" } ]
      )
    ).debugging_case
  end

  describe "GET /debugging_cases/:id/edit" do
    it "redirects guests to sign in" do
      get edit_debugging_case_path(debugging_case)

      expect(response).to redirect_to(new_user_session_path)
    end

    it "returns not found for another user's case" do
      sign_in other_user

      get edit_debugging_case_path(debugging_case)

      expect(response).to have_http_status(:not_found)
    end

    it "renders the edit form for the owner" do
      sign_in owner

      get edit_debugging_case_path(debugging_case)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit debugging case")
      expect(response.body).to include('value="Original title"')
      expect(response.body).to include("Original description")
    end
  end

  describe "PATCH /debugging_cases/:id" do
    let(:update_params) do
      {
        debugging_case: {
          title: "Updated title",
          description: "Updated description",
          customer_reference: "Ticket #2",
          environment: "production"
        }
      }
    end

    it "redirects guests to sign in" do
      patch debugging_case_path(debugging_case), params: update_params

      expect(response).to redirect_to(new_user_session_path)
      expect(debugging_case.reload.title).to eq("Original title")
    end

    it "returns not found for another user's case" do
      sign_in other_user

      patch debugging_case_path(debugging_case), params: update_params

      expect(response).to have_http_status(:not_found)
      expect(debugging_case.reload.title).to eq("Original title")
    end

    it "updates metadata for the owner" do
      sign_in owner

      patch debugging_case_path(debugging_case), params: update_params

      expect(response).to redirect_to(debugging_case_path(debugging_case))
      expect(flash[:notice]).to eq("Case updated.")

      debugging_case.reload
      expect(debugging_case.title).to eq("Updated title")
      expect(debugging_case.description).to eq("Updated description")
      expect(debugging_case.customer_reference).to eq("Ticket #2")
      expect(debugging_case.environment).to eq("production")
    end

    it "does not change log sources on update" do
      sign_in owner
      original_source_ids = debugging_case.log_source_ids

      patch debugging_case_path(debugging_case), params: update_params

      expect(debugging_case.reload.log_source_ids).to eq(original_source_ids)
    end

    it "rejects mass-assignment of user_id and archived_at on update" do
      other = create(:user, email: "mass-update-#{SecureRandom.hex(4)}@example.com")
      sign_in owner

      patch debugging_case_path(debugging_case), params: update_params.deep_merge(
        debugging_case: {
          user_id: other.id,
          archived_at: Time.current
        }
      )

      debugging_case.reload
      expect(debugging_case.user).to eq(owner)
      expect(debugging_case.archived_at).to be_nil
    end

    it "re-renders edit with 422 when title is blank" do
      sign_in owner

      patch debugging_case_path(debugging_case), params: {
        debugging_case: { title: "" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Edit debugging case")
      expect(response.body).to include("Title can&#39;t be blank")
      expect(debugging_case.reload.title).to eq("Original title")
    end
  end
end
