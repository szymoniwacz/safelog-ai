# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Debugging case analyze security (AGENTS.md guardrails)", type: :request do
  let(:user) { create(:user, email: "analyze-security@example.com") }
  let(:fake_client) { Ai::FakeClient.new }
  let(:secret_email) { "agents-analyze-#{SecureRandom.hex(4)}@secret.example" }
  let(:secret_token) { "sk-agents-analyze-#{SecureRandom.hex(8)}" }
  let(:shared_request_id) { "req-analyze-sec-#{SecureRandom.hex(6)}" }

  before do
    allow(Ai::ClientResolver).to receive(:current).and_return(fake_client)
  end

  def submission_params
    {
      debugging_case: {
        title: "Analyze security case",
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

  describe "POST /debugging_cases/:id/analyze" do
    before do
      sign_in user
      post debugging_cases_path, params: submission_params
      follow_redirect!
    end

    it "does not send raw intake secrets to the AI client (AGENTS.md)" do
      debugging_case = DebuggingCase.last

      post analyze_debugging_case_path(debugging_case)
      follow_redirect!

      prompt = fake_client.last_request.messages.map { |message| message[:content] }.join("\n")

      expect(prompt).to include("[EMAIL_1]")
      expect(prompt).to include("[AUTH_1]")
      expect(prompt).to include("[REQUEST_1]")
      expect(prompt).not_to include(secret_email)
      expect(prompt).not_to include(secret_token)
      expect(prompt).not_to include(shared_request_id)
    end

    it "does not persist raw secrets in correlation signal payload (AGENTS.md)" do
      debugging_case = DebuggingCase.last

      post analyze_debugging_case_path(debugging_case)

      correlation_signal = debugging_case.reload.correlation_signals.last
      payload = correlation_signal.payload

      expect(payload).to include("[REQUEST_1]")
      expect(payload).not_to include(secret_email)
      expect(payload).not_to include(secret_token)
      expect(payload).not_to include(shared_request_id)
    end

    it "does not expose raw secrets in the post-analyze show response (AGENTS.md)" do
      debugging_case = DebuggingCase.last

      post analyze_debugging_case_path(debugging_case)
      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("[EMAIL_1]")
      expect(response.body).not_to include(secret_email)
      expect(response.body).not_to include(secret_token)
      expect(response.body).not_to include(shared_request_id)
    end
  end
end
