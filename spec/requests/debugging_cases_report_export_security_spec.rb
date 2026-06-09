# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Debugging case report export security (AGENTS.md guardrails)", type: :request do
  let(:owner) { create(:user, email: "export-security@example.com") }
  let(:other_user) { create(:user, email: "other-export-security@example.com") }
  let(:fake_client) { Ai::FakeClient.new }
  let(:secret_email) { "agents-export-#{SecureRandom.hex(4)}@secret.example" }
  let(:secret_token) { "sk-agents-export-#{SecureRandom.hex(8)}" }
  let(:shared_request_id) { "req-export-sec-#{SecureRandom.hex(6)}" }

  before do
    allow(Ai::ClientResolver).to receive(:current).and_return(fake_client)
  end

  def submission_params
    {
      debugging_case: {
        title: "Export security case",
        customer_reference: "Contact #{secret_email}",
        sources: [
          {
            source_type: "rails_log",
            pasted_content: <<~LOG.strip
              User login failed for #{secret_email}
              Authorization: Bearer #{secret_token}
            LOG
          },
          {
            source_type: "aws_cloudwatch",
            pasted_content: "Timeout for request_id=#{shared_request_id}"
          }
        ]
      }
    }
  end

  let!(:debugging_case) do
    sign_in owner
    post debugging_cases_path, params: submission_params
    follow_redirect!
    DebuggingCase.last
  end

  before do
    post analyze_debugging_case_path(debugging_case)
    expect(response).to redirect_to(debugging_case_path(debugging_case))
  end

  describe "GET /debugging_cases/:id/download_report" do
    it "does not include raw intake secrets in the downloaded markdown (AGENTS.md)" do
      sign_in owner

      get download_report_debugging_case_path(debugging_case)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("[REQUEST_1]")
      expect(response.body).not_to include(secret_email)
      expect(response.body).not_to include(secret_token)
      expect(response.body).not_to include(shared_request_id)
    end

    it "does not expose raw secrets in the show page markdown textarea (AGENTS.md)" do
      sign_in owner

      get debugging_case_path(debugging_case)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("## Hypothesis report")
      expect(response.body).to include('aria-label="Report Markdown"')
      expect(response.body).to include("[REQUEST_1]")
      expect(response.body).not_to include(secret_email)
      expect(response.body).not_to include(secret_token)
      expect(response.body).not_to include(shared_request_id)
    end

    it "returns not found when another user downloads after analyze" do
      sign_in other_user

      get download_report_debugging_case_path(debugging_case)

      expect(response).to have_http_status(:not_found)
    end
  end
end
