# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Debugging cases security (AGENTS.md guardrails)", type: :request do
  let(:user) { create(:user, email: "security@example.com") }
  let(:secret_email) { "agents-md-#{SecureRandom.hex(4)}@secret.example" }
  let(:secret_token) { "sk-agents-md-#{SecureRandom.hex(8)}" }
  let(:shared_request_id) { "req-http-#{SecureRandom.hex(6)}" }

  def submission_params
    {
      debugging_case: {
        title: "Security guardrail case",
        description: "Validates sanitized persistence only",
        customer_reference: "Contact #{secret_email}",
        environment: "production",
        sources: [
          {
            source_type: "rails_log",
            name: "Rails",
            pasted_content: <<~LOG.strip
              User login failed for #{secret_email}
              Authorization: Bearer #{secret_token}
            LOG
          },
          {
            source_type: "aws_cloudwatch",
            name: "CloudWatch",
            pasted_content: "Timeout for request_id=#{shared_request_id}"
          },
          {
            source_type: "browser_console",
            name: "Browser",
            pasted_content: "Error for request_id=#{shared_request_id}"
          }
        ]
      }
    }
  end

  describe "POST /debugging_cases" do
    before do
      sign_in user
      post debugging_cases_path, params: submission_params
      follow_redirect!
    end

    it "does not persist raw log substrings in diagnostic text columns (AGENTS.md)" do
      assert_no_raw_substring_in_persisted_data(secret_email)
      assert_no_raw_substring_in_persisted_data(secret_token)
      assert_no_raw_substring_in_persisted_data(shared_request_id)
    end

    it "does not expose raw secrets in the show response (AGENTS.md)" do
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(secret_email)
      expect(response.body).not_to include(secret_token)
      expect(response.body).not_to include(shared_request_id)
      expect(response.body).to include("[EMAIL_1]")
      expect(response.body).to include("[AUTH_1]")
    end

    it "correlates shared request ids across sources in the HTTP intake flow" do
      expect(response.body.scan("[REQUEST_1]").size).to be >= 2
    end
  end

  # Test-env log/test.log only; see spec/support/log_guard_operational_checklist.md
  describe "Rails test log guard" do
    it "does not write raw intake secrets to log/test.log after POST /debugging_cases (AGENTS.md)" do
      log_offset = SecurityPersistenceHelpers::TEST_LOG_PATH.exist? ? SecurityPersistenceHelpers::TEST_LOG_PATH.size : 0

      sign_in user
      post debugging_cases_path, params: submission_params

      assert_no_raw_substring_in_appended_test_log(secret_email, from_offset: log_offset)
      assert_no_raw_substring_in_appended_test_log(secret_token, from_offset: log_offset)
      assert_no_raw_substring_in_appended_test_log(shared_request_id, from_offset: log_offset)
    end
  end

  describe "description metadata redaction" do
    let(:description_secret_email) { "desc-meta-#{SecureRandom.hex(4)}@secret.example" }
    let(:fake_client) { Ai::FakeClient.new }

    before do
      allow(Ai::ClientResolver).to receive(:current).and_return(fake_client)
      sign_in user
      post debugging_cases_path, params: {
        debugging_case: {
          title: "Metadata redaction case",
          description: "Reporter contact: #{description_secret_email}",
          sources: [
            { source_type: "rails_log", pasted_content: "Started GET /health" }
          ]
        }
      }
      follow_redirect!
    end

    it "redacts secrets in description on persist and in analyze prompts" do
      debugging_case = DebuggingCase.last

      expect(debugging_case.description).to include("[EMAIL_1]")
      expect(debugging_case.description).not_to include(description_secret_email)

      post analyze_debugging_case_path(debugging_case)
      follow_redirect!

      prompt = fake_client.last_request.messages.map { |message| message[:content] }.join("\n")
      expect(prompt).to include("[EMAIL_1]")
      expect(prompt).not_to include(description_secret_email)
    end
  end

  describe "title metadata redaction" do
    let(:title_secret_email) { "title-meta-#{SecureRandom.hex(4)}@secret.example" }
    let(:fake_client) { Ai::FakeClient.new }

    before do
      allow(Ai::ClientResolver).to receive(:current).and_return(fake_client)
      sign_in user
      post debugging_cases_path, params: {
        debugging_case: {
          title: "Incident for #{title_secret_email}",
          description: "Payment step hangs",
          sources: [
            { source_type: "rails_log", pasted_content: "Started GET /health" }
          ]
        }
      }
      follow_redirect!
    end

    it "redacts secrets in title on persist, show, and analyze prompts" do
      debugging_case = DebuggingCase.last

      expect(debugging_case.title).to include("[EMAIL_1]")
      expect(debugging_case.title).not_to include(title_secret_email)
      expect(response.body).not_to include(title_secret_email)

      post analyze_debugging_case_path(debugging_case)
      follow_redirect!

      prompt = fake_client.last_request.messages.map { |message| message[:content] }.join("\n")
      expect(prompt).to include("[EMAIL_1]")
      expect(prompt).not_to include(title_secret_email)
    end
  end

  describe "customer_reference metadata redaction" do
    let(:customer_reference_secret_email) { "cust-ref-#{SecureRandom.hex(4)}@secret.example" }

    before do
      sign_in user
      post debugging_cases_path, params: {
        debugging_case: {
          title: "Customer reference redaction case",
          description: "Payment step hangs",
          customer_reference: "Contact #{customer_reference_secret_email}",
          sources: [
            { source_type: "rails_log", pasted_content: "Started GET /health" }
          ]
        }
      }
      follow_redirect!
    end

    it "redacts secrets in customer_reference on persist and show" do
      debugging_case = DebuggingCase.last

      expect(debugging_case.customer_reference).to include("[EMAIL_1]")
      expect(debugging_case.customer_reference).not_to include(customer_reference_secret_email)
      expect(response.body).not_to include(customer_reference_secret_email)

      assert_no_raw_substring_in_persisted_data(customer_reference_secret_email)
    end
  end

  describe "source name redaction" do
    let(:source_name_secret_email) { "src-name-#{SecureRandom.hex(4)}@secret.example" }
    let(:fake_client) { Ai::FakeClient.new }

    before do
      allow(Ai::ClientResolver).to receive(:current).and_return(fake_client)
      sign_in user
      post debugging_cases_path, params: {
        debugging_case: {
          title: "Source name redaction case",
          description: "Payment step hangs",
          sources: [
            {
              source_type: "rails_log",
              name: "Reporter #{source_name_secret_email}",
              pasted_content: "Started GET /health"
            }
          ]
        }
      }
      follow_redirect!
    end

    it "redacts secrets in source name on persist, show, and analyze prompts" do
      debugging_case = DebuggingCase.last
      log_source = debugging_case.log_sources.first

      expect(log_source.name).to include("[EMAIL_1]")
      expect(log_source.name).not_to include(source_name_secret_email)
      expect(response.body).not_to include(source_name_secret_email)

      assert_no_raw_substring_in_persisted_data(source_name_secret_email)

      post analyze_debugging_case_path(debugging_case)
      follow_redirect!

      prompt = fake_client.last_request.messages.map { |message| message[:content] }.join("\n")
      expect(prompt).to include("[EMAIL_1]")
      expect(prompt).not_to include(source_name_secret_email)
    end
  end

  describe "validation failure safety" do
    it "does not re-render raw pasted content after a validation error (AGENTS.md)" do
      pasted_secret = "val-fail-#{SecureRandom.hex(4)}@secret.example"

      sign_in user
      post debugging_cases_path, params: {
        debugging_case: {
          title: "",
          sources: [
            { source_type: "rails_log", pasted_content: pasted_secret }
          ]
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).not_to include(pasted_secret)
      expect(response.body).to include('aria-invalid="true"')
    end
  end

  describe "environment metadata redaction" do
    let(:environment_secret_email) { "env-meta-#{SecureRandom.hex(4)}@secret.example" }
    let(:fake_client) { Ai::FakeClient.new }

    before do
      allow(Ai::ClientResolver).to receive(:current).and_return(fake_client)
      sign_in user
      post debugging_cases_path, params: {
        debugging_case: {
          title: "Metadata redaction case",
          description: "Payment step hangs",
          environment: "Contact #{environment_secret_email}",
          sources: [
            { source_type: "rails_log", pasted_content: "Started GET /health" }
          ]
        }
      }
      follow_redirect!
    end

    it "redacts secrets in environment on persist, show, and analyze prompts" do
      debugging_case = DebuggingCase.last

      expect(debugging_case.environment).to include("[EMAIL_1]")
      expect(debugging_case.environment).not_to include(environment_secret_email)
      expect(response.body).not_to include(environment_secret_email)

      assert_no_raw_substring_in_persisted_data(environment_secret_email)

      post analyze_debugging_case_path(debugging_case)
      follow_redirect!

      prompt = fake_client.last_request.messages.map { |message| message[:content] }.join("\n")
      expect(prompt).to include("[EMAIL_1]")
      expect(prompt).not_to include(environment_secret_email)
    end
  end
end
