# frozen_string_literal: true

require "rails_helper"

RSpec.describe Correlation::ExtractSignals do
  let(:user) { create(:user) }

  def create_case_from_submission(submission_attrs)
    submission = Intake::CaseSubmission.new(submission_attrs)
    Intake::ProcessCaseSubmission.call(user: user, submission: submission).debugging_case
  end

  describe ".call" do
    it "returns a shared placeholder signal across two log sources" do
      debugging_case = create_case_from_submission(
        title: "Shared request id",
        sources: [
          {
            source_type: "rails_log",
            pasted_content: "Started GET /checkout request_id=req-shared-999"
          },
          {
            source_type: "aws_cloudwatch",
            pasted_content: "Timeout waiting for request_id=req-shared-999"
          }
        ]
      )

      result = described_class.call(debugging_case: debugging_case)

      expect(result[:signals].size).to eq(1)
      signal = result[:signals].first
      expect(signal[:placeholder]).to eq("[REQUEST_1]")
      expect(signal[:occurrence_count]).to be >= 2
      expect(signal[:source_types]).to contain_exactly("aws_cloudwatch", "rails_log")
      expect(signal[:finding_types]).to include("request_id")
    end

    it "returns a single-source signal with occurrence count one" do
      secret_email = "signal-#{SecureRandom.hex(4)}@secret.example"

      debugging_case = create_case_from_submission(
        title: "Single email signal",
        sources: [
          {
            source_type: "rails_log",
            pasted_content: "User login failed for #{secret_email}"
          }
        ]
      )

      result = described_class.call(debugging_case: debugging_case)

      expect(result[:signals].size).to eq(1)
      signal = result[:signals].first
      expect(signal[:placeholder]).to eq("[EMAIL_1]")
      expect(signal[:occurrence_count]).to eq(1)
      expect(signal[:source_types]).to eq([ "rails_log" ])
      expect(signal[:finding_types]).to include("email")
    end

    it "does not include raw intake secrets in the payload" do
      secret_email = "payload-#{SecureRandom.hex(4)}@secret.example"
      secret_token = "sk-payload-#{SecureRandom.hex(8)}"

      debugging_case = create_case_from_submission(
        title: "Secret-free payload",
        sources: [
          {
            source_type: "rails_log",
            pasted_content: <<~LOG.strip
              Failed for #{secret_email}
              Authorization: Bearer #{secret_token}
            LOG
          }
        ]
      )

      result = described_class.call(debugging_case: debugging_case)
      payload = result.to_json

      expect(payload).not_to include(secret_email)
      expect(payload).not_to include(secret_token)
      expect(payload).to include("[EMAIL_1]")
      expect(payload).to include("[AUTH_1]")
    end

    it "returns an empty signals array when no placeholders are present" do
      debugging_case = create_case_from_submission(
        title: "Plain logs",
        sources: [
          { source_type: "rails_log", pasted_content: "Started GET /health" }
        ]
      )

      result = described_class.call(debugging_case: debugging_case)

      expect(result[:signals]).to eq([])
    end
  end
end
