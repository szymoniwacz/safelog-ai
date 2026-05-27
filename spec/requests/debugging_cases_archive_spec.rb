# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Debugging case archive", type: :request do
  let(:owner) { create(:user, email: "archive@example.com") }
  let(:other_user) { create(:user, email: "other-archive@example.com") }

  let!(:debugging_case) do
    Intake::ProcessCaseSubmission.call(
      user: owner,
      submission: Intake::CaseSubmission.new(
        title: "Archive me",
        sources: [ { source_type: "rails_log", pasted_content: "request_id=req-archive-1" } ]
      )
    ).debugging_case
  end

  describe "POST /debugging_cases/:id/archive" do
    it "redirects guests to sign in" do
      post archive_debugging_case_path(debugging_case)

      expect(response).to redirect_to(new_user_session_path)
      expect(debugging_case.reload.archived_at).to be_nil
    end

    it "returns not found for another user's case" do
      sign_in other_user

      post archive_debugging_case_path(debugging_case)

      expect(response).to have_http_status(:not_found)
      expect(debugging_case.reload.archived_at).to be_nil
    end

    it "archives the case for the owner" do
      sign_in owner

      post archive_debugging_case_path(debugging_case)

      expect(response).to redirect_to(debugging_cases_path)
      expect(flash[:notice]).to eq("Case archived.")
      expect(debugging_case.reload.archived_at).to be_present
      expect(debugging_case).to be_archived
    end
  end
end
