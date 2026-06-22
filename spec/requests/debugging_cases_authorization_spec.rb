# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Debugging cases authorization", type: :request do
  let(:owner) { create(:user, email: "owner@example.com") }
  let(:other_user) { create(:user, email: "other@example.com") }
  let(:generated_report_summary) { "Test case hypothesis report" }

  let!(:debugging_case) do
    result = Intake::ProcessCaseSubmission.call(
      user: owner,
      submission: Intake::CaseSubmission.new(
        title: "Owner-only case",
        sources: [
          { source_type: "rails_log", pasted_content: "request_id=req-owner-only-1" }
        ]
      )
    )
    result.debugging_case
  end

  describe "GET /debugging_cases/:id" do
    it "returns not found for another user's case" do
      sign_in other_user

      get debugging_case_path(debugging_case)

      expect_not_found_without_forbidden
      # Title literals from this spec can appear in local error-page stack traces;
      # assert case-specific show content instead (risk #3 body-leak oracle).
      expect(response.body).not_to include("[REQUEST_1]")
      expect(response.body).not_to include("req-owner-only-1")
    end

    it "returns success for the owning user" do
      sign_in owner

      get debugging_case_path(debugging_case)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Owner-only case")
      expect(response.body).to include("[REQUEST_1]")
      expect(response.body).not_to include("req-owner-only-1")
    end
  end

  describe "POST /debugging_cases/:id/analyze" do
    it "returns not found for another user's case" do
      sign_in other_user

      expect {
        post analyze_debugging_case_path(debugging_case)
      }.not_to change { debugging_case.reload.correlation_signals.count }

      expect_not_found_without_forbidden
      expect(debugging_case.ai_reports.count).to eq(0)
    end
  end

  describe "POST /debugging_cases/:id/archive" do
    it "returns not found for another user's case" do
      sign_in other_user

      post archive_debugging_case_path(debugging_case)

      expect_not_found_without_forbidden
      expect(debugging_case.reload.archived_at).to be_nil
    end
  end

  describe "GET /debugging_cases/:id/download_report" do
    it "returns not found for another user's case" do
      sign_in other_user

      get download_report_debugging_case_path(debugging_case)

      expect_not_found_without_forbidden
    end

    it "returns not found for another user when the owner has a generated report" do
      fake_client = Ai::FakeClient.new
      allow(Ai::ClientResolver).to receive(:current).and_return(fake_client)

      sign_in owner
      post analyze_debugging_case_path(debugging_case)
      expect(response).to redirect_to(debugging_case_path(debugging_case))
      expect(debugging_case.reload.ai_reports.last).to be_generated

      sign_in other_user
      get download_report_debugging_case_path(debugging_case)

      expect_not_found_without_forbidden
      expect(response.body).not_to include(generated_report_summary)
    end
  end
end
