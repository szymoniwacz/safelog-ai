# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Debugging case analyze", type: :request do
  let(:owner) { create(:user, email: "owner@example.com") }
  let(:other_user) { create(:user, email: "other@example.com") }

  let!(:debugging_case) do
    result = Intake::ProcessCaseSubmission.call(
      user: owner,
      submission: Intake::CaseSubmission.new(
        title: "Analyze this case",
        sources: [
          {
            source_type: "rails_log",
            pasted_content: "request_id=req-analyze-http-1"
          },
          {
            source_type: "aws_cloudwatch",
            pasted_content: "Timeout for request_id=req-analyze-http-1"
          }
        ]
      )
    )
    result.debugging_case
  end

  describe "POST /debugging_cases/:id/analyze" do
    it "redirects guests to sign in" do
      post analyze_debugging_case_path(debugging_case)

      expect(response).to redirect_to(new_user_session_path)
    end

    it "returns not found for another user's case" do
      sign_in other_user

      post analyze_debugging_case_path(debugging_case)

      expect(response).to have_http_status(:not_found)
      expect(debugging_case.ai_reports.count).to eq(0)
    end

    it "runs analyze for the owner and redirects to the case show page" do
      sign_in owner

      post analyze_debugging_case_path(debugging_case)

      expect(response).to redirect_to(debugging_case_path(debugging_case))

      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(flash[:notice]).to eq("Analysis complete.")
      expect(response.body).to include("Hypothesis report")
      expect(response.body).to include("Checkout timeout may be caused by downstream payment latency.")
      expect(response.body).to include("[REQUEST_1]")
      expect(response.body).not_to include("req-analyze-http-1")
      expect(response.body).to include("Markdown export")
      expect(response.body).to include("## Hypothesis report")
      expect(response.body).to include("download the report")

      ai_report = debugging_case.reload.ai_reports.order(:created_at).last
      expect(ai_report).to be_generated
      expect(ai_report.structured_json).to be_present
      expect(debugging_case.correlation_signals.count).to eq(1)
    end

    it "surfaces a safe failure after retry exhaustion" do
      invalid_client = AiTestClients::InvalidClient.new
      allow(Ai::ClientResolver).to receive(:current).and_return(invalid_client)

      sign_in owner

      post analyze_debugging_case_path(debugging_case)

      expect(response).to redirect_to(debugging_case_path(debugging_case))
      expect(flash[:alert]).to eq(Analysis::AnalyzeCase::FAILURE_MESSAGE)

      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(Analysis::AnalyzeCase::FAILURE_MESSAGE)
      expect(response.body).not_to include("Checkout timeout may be caused by downstream payment latency.")

      ai_report = debugging_case.reload.ai_reports.order(:created_at).last
      expect(ai_report).to be_failed
      expect(ai_report.structured_json).to be_nil
      expect(ai_report.markdown_body).to be_nil
      expect(invalid_client.complete_calls).to eq(2)

      get download_report_debugging_case_path(debugging_case)

      expect(response).to have_http_status(:not_found)
    end

    it "does not read the E2E AI client header outside the test environment" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
      allow(Ai::ClientResolver).to receive(:current).and_return(Ai::FakeClient.new)

      sign_in owner

      post analyze_debugging_case_path(debugging_case), headers: { "X-E2E-AI-Client" => "invalid" }

      expect(response).to redirect_to(debugging_case_path(debugging_case))
      expect(flash[:notice]).to eq("Analysis complete.")
      expect(Ai::E2eContext.client_mode).to be_nil
    end

    it "uses the E2E AI client mode header in test" do
      sign_in owner

      post analyze_debugging_case_path(debugging_case), headers: { "X-E2E-AI-Client" => "invalid" }

      expect(response).to redirect_to(debugging_case_path(debugging_case))
      expect(flash[:alert]).to eq(Analysis::AnalyzeCase::FAILURE_MESSAGE)
      expect(Ai::E2eContext.client_mode).to be_nil
    end

    it "ignores the E2E AI client mode header outside test" do
      sign_in owner
      allow(Rails.env).to receive(:test?).and_return(false)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return(nil)

      post analyze_debugging_case_path(debugging_case), headers: { "X-E2E-AI-Client" => "invalid" }

      expect(response).to redirect_to(debugging_case_path(debugging_case))
      expect(flash[:notice]).to eq("Analysis complete.")
      expect(Ai::E2eContext.client_mode).to be_nil
    end
  end
end
