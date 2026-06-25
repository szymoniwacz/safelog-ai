# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Debugging case destroy", type: :request do
  let(:owner) { create(:user, email: "destroy@example.com") }
  let(:other_user) { create(:user, email: "other-destroy@example.com") }

  let!(:debugging_case) do
    Intake::ProcessCaseSubmission.call(
      user: owner,
      submission: Intake::CaseSubmission.new(
        title: "Delete me",
        sources: [ { source_type: "rails_log", pasted_content: "request_id=req-destroy-1" } ]
      )
    ).debugging_case
  end

  describe "DELETE /debugging_cases/:id" do
    it "redirects guests to sign in" do
      expect {
        delete debugging_case_path(debugging_case)
      }.not_to change(DebuggingCase, :count)

      expect(response).to redirect_to(new_user_session_path)
    end

    it "returns not found for another user's case" do
      sign_in other_user

      expect {
        delete debugging_case_path(debugging_case)
      }.not_to change(DebuggingCase, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "deletes the case and associated records for the owner" do
      sign_in owner
      log_source = debugging_case.log_sources.first
      finding = log_source.redaction_findings.first

      expect {
        delete debugging_case_path(debugging_case)
      }.to change(DebuggingCase, :count).by(-1)
        .and change(LogSource, :count).by(-1)
        .and change(RedactionFinding, :count).by(-1)

      expect(response).to redirect_to(debugging_cases_path)
      expect(flash[:notice]).to eq("Case deleted.")
      expect { debugging_case.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { log_source.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { finding.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
