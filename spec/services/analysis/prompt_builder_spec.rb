# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analysis::PromptBuilder do
  let(:user) { create(:user) }

  def create_case_from_submission(submission_attrs)
    submission = Intake::CaseSubmission.new(submission_attrs)
    Intake::ProcessCaseSubmission.call(user: user, submission: submission).debugging_case
  end

  describe ".call" do
    it "builds a sanitized AI request with placeholders and correlation payload" do
      secret_email = "prompt-#{SecureRandom.hex(4)}@secret.example"

      debugging_case = create_case_from_submission(
        title: "Checkout failure",
        environment: "production",
        customer_reference: "Ticket #12345",
        description: "Payment step hangs",
        sources: [
          {
            source_type: "rails_log",
            name: "Rails",
            pasted_content: "User login failed for #{secret_email}"
          }
        ]
      )

      correlation_payload = Correlation::ExtractSignals.call(debugging_case: debugging_case)
      request = described_class.call(
        debugging_case: debugging_case,
        correlation_payload: correlation_payload
      )

      content = request.messages.map { |message| message[:content] }.join("\n")

      expect(content).to include("[EMAIL_1]")
      expect(content).to include("Checkout failure")
      expect(content).to include("Correlation signals:")
      expect(content).not_to include(secret_email)
      expect(request.case_ref).to eq(debugging_case.id.to_s)
    end

    it "instructs the model to return JSON for OpenAI json_object mode" do
      debugging_case = create_case_from_submission(
        title: "Checkout failure",
        sources: [
          { source_type: "rails_log", pasted_content: "request_id=req-json-prompt-1" }
        ]
      )
      correlation_payload = Correlation::ExtractSignals.call(debugging_case: debugging_case)
      request = described_class.call(
        debugging_case: debugging_case,
        correlation_payload: correlation_payload
      )

      system_content = request.messages.find { |message| message[:role] == "system" }[:content]

      expect(system_content).to match(/json/i)
      expect(system_content).to include('"structured"')
      expect(system_content).to include('"markdown"')
    end

    it "excludes environment metadata-only secrets from the assembled prompt" do
      secret_email = "env-prompt-#{SecureRandom.hex(4)}@secret.example"

      debugging_case = create_case_from_submission(
        title: "Checkout failure",
        environment: "Contact #{secret_email}",
        customer_reference: "Ticket #12345",
        description: "Payment step hangs",
        sources: [
          {
            source_type: "rails_log",
            name: "Rails",
            pasted_content: "Started GET /health"
          }
        ]
      )

      correlation_payload = Correlation::ExtractSignals.call(debugging_case: debugging_case)
      request = described_class.call(
        debugging_case: debugging_case,
        correlation_payload: correlation_payload
      )

      content = request.messages.map { |message| message[:content] }.join("\n")

      expect(content).to include("[EMAIL_1]")
      expect(content).not_to include(secret_email)
    end

    it "excludes metadata-only secrets from the assembled prompt" do
      secret_email = "meta-prompt-#{SecureRandom.hex(4)}@secret.example"

      debugging_case = create_case_from_submission(
        title: "Checkout failure",
        environment: "production",
        customer_reference: "Contact #{secret_email}",
        description: "Payment step hangs",
        sources: [
          {
            source_type: "rails_log",
            name: "Rails",
            pasted_content: "Started GET /health"
          }
        ]
      )

      correlation_payload = Correlation::ExtractSignals.call(debugging_case: debugging_case)
      request = described_class.call(
        debugging_case: debugging_case,
        correlation_payload: correlation_payload
      )

      content = request.messages.map { |message| message[:content] }.join("\n")

      expect(content).to include("[EMAIL_1]")
      expect(content).not_to include(secret_email)
    end

    it "serializes correlation signals as compact JSON" do
      debugging_case = create_case_from_submission(
        title: "Compact JSON",
        sources: [
          { source_type: "rails_log", pasted_content: "request_id=req-compact-json-1" }
        ]
      )
      correlation_payload = Correlation::ExtractSignals.call(debugging_case: debugging_case)
      request = described_class.call(
        debugging_case: debugging_case,
        correlation_payload: correlation_payload
      )

      user_content = request.messages.find { |message| message[:role] == "user" }[:content]

      expect(user_content).to include("Correlation signals:\n#{JSON.generate(correlation_payload)}")
      expect(user_content).not_to match(/Correlation signals:\n{\n/)
    end

    it "reuses loaded log sources without a second log_sources query" do
      debugging_case = create_case_from_submission(
        title: "Loaded sources",
        sources: [
          { source_type: "rails_log", pasted_content: "request_id=req-loaded-sources-1" },
          { source_type: "browser_console", pasted_content: "request_id=req-loaded-sources-1" }
        ]
      )
      correlation_payload = Correlation::ExtractSignals.call(debugging_case: debugging_case)
      expect(debugging_case.association(:log_sources)).to be_loaded

      query_count = 0
      counter = lambda do |*, payload|
        query_count += 1 if payload[:sql].match?(/FROM "#{LogSource.table_name}"/i)
      end

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        described_class.call(
          debugging_case: debugging_case,
          correlation_payload: correlation_payload
        )
      end

      expect(query_count).to eq(0)
    end
  end
end
