# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Debugging case report export", type: :request do
  let(:owner) { create(:user, email: "export@example.com") }
  let(:other_user) { create(:user, email: "other-export@example.com") }

  let!(:debugging_case) do
    result = Intake::ProcessCaseSubmission.call(
      user: owner,
      submission: Intake::CaseSubmission.new(
        title: "Checkout Timeout",
        sources: [
          { source_type: "rails_log", pasted_content: "request_id=req-export-1" }
        ]
      )
    )
    result.debugging_case
  end

  describe "GET /debugging_cases/:id/download_report" do
    it "redirects guests to sign in" do
      get download_report_debugging_case_path(debugging_case)

      expect(response).to redirect_to(new_user_session_path)
    end

    it "returns not found when no generated report exists" do
      sign_in owner

      get download_report_debugging_case_path(debugging_case)

      expect(response).to have_http_status(:not_found)
    end

    it "returns not found for another user's case" do
      sign_in other_user

      get download_report_debugging_case_path(debugging_case)

      expect(response).to have_http_status(:not_found)
    end

    it "downloads markdown for the owner after analyze" do
      sign_in owner
      post analyze_debugging_case_path(debugging_case)
      expect(response).to redirect_to(debugging_case_path(debugging_case))

      get download_report_debugging_case_path(debugging_case)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/markdown")
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.headers["Content-Disposition"]).to include("checkout-timeout-report.md")
      expect(response.body).to include("## Hypothesis report")
      expect(response.body).to include("[REQUEST_1]")
      expect(response.body).not_to include("req-export-1")
    end
  end
end
