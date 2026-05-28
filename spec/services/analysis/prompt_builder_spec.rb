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
  end
end
