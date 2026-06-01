# frozen_string_literal: true

require "rails_helper"

RSpec.describe Intake::ProcessCaseSubmission do
  let(:user) { create(:user) }

  def build_submission(overrides = {})
    defaults = {
      title: "Checkout timeout",
      description: "Customer cannot complete payment",
      customer_reference: "request_id=req-shared-999",
      environment: "production",
      sources: [
        {
          source_type: "rails_log",
          name: "Rails",
          pasted_content: "Started GET /checkout request_id=req-shared-999"
        },
        {
          source_type: "aws_cloudwatch",
          name: "CloudWatch",
          pasted_content: "Timeout waiting for request_id=req-shared-999"
        }
      ]
    }

    Intake::CaseSubmission.new(defaults.merge(overrides))
  end

  describe ".call" do
    it "creates a case with sanitized sources and persisted findings" do
      secret_email = "leak-#{SecureRandom.hex(4)}@secret.example"
      secret_token = "sk-leak-#{SecureRandom.hex(8)}"

      submission = build_submission(
        sources: [
          {
            source_type: "rails_log",
            name: "Rails",
            pasted_content: "User login failed for #{secret_email}\nAuthorization: Bearer #{secret_token}"
          },
          {
            source_type: "browser_console",
            name: "Browser",
            pasted_content: "request_id=req-shared-999"
          }
        ]
      )

      result = described_class.call(user: user, submission: submission)

      expect(result).to be_success
      debugging_case = result.debugging_case
      expect(debugging_case).to be_persisted
      expect(debugging_case.log_sources.count).to eq(2)
      expect(debugging_case.log_sources.flat_map(&:redaction_findings).count).to be > 0

      rails_source = debugging_case.log_sources.find_by!(source_type: "rails_log")
      browser_source = debugging_case.log_sources.find_by!(source_type: "browser_console")

      expect(rails_source.sanitized_content).to include("[EMAIL_1]")
      expect(rails_source.sanitized_content).to include("[AUTH_1]")
      expect(rails_source.sanitized_content).not_to include(secret_email)
      expect(rails_source.sanitized_content).not_to include(secret_token)

      expect(browser_source.sanitized_content).to include("[REQUEST_1]")
      expect(rails_source.sanitized_content).not_to include("req-shared-999")
      expect(browser_source.sanitized_content).not_to include("req-shared-999")
    end

    it "reuses placeholders across sources and customer_reference via shared registry" do
      submission = build_submission

      result = described_class.call(user: user, submission: submission)

      expect(result).to be_success

      debugging_case = result.debugging_case.reload
      sanitized_bodies = debugging_case.log_sources.order(:position).map(&:sanitized_content)

      expect(sanitized_bodies).to all(include("[REQUEST_1]"))
      expect(debugging_case.customer_reference).to include("[REQUEST_1]")
      expect(debugging_case.customer_reference).not_to include("req-shared-999")
    end

    it "does not persist raw secrets in encrypted diagnostic fields" do
      secret_email = "persist-#{SecureRandom.hex(4)}@secret.example"

      submission = build_submission(
        customer_reference: "Contact #{secret_email}",
        sources: [
          {
            source_type: "rails_log",
            pasted_content: "Failed for #{secret_email}"
          }
        ]
      )

      result = described_class.call(user: user, submission: submission)
      expect(result).to be_success

      assert_no_raw_substring_in_persisted_data(secret_email)
    end

    it "redacts secrets in title and description metadata on persist" do
      title_secret = "title-intake-#{SecureRandom.hex(4)}@secret.example"
      description_secret = "desc-intake-#{SecureRandom.hex(4)}@secret.example"

      submission = build_submission(
        title: "Incident for #{title_secret}",
        description: "Reporter contact: #{description_secret}",
        customer_reference: "Ticket #12345",
        sources: [
          {
            source_type: "rails_log",
            pasted_content: "Started GET /health"
          }
        ]
      )

      result = described_class.call(user: user, submission: submission)
      expect(result).to be_success

      debugging_case = result.debugging_case
      expect(debugging_case.title).to include("[EMAIL_1]")
      expect(debugging_case.title).not_to include(title_secret)
      expect(debugging_case.description).to include("[EMAIL_2]")
      expect(debugging_case.description).not_to include(description_secret)

      assert_no_raw_substring_in_persisted_data(title_secret)
      assert_no_raw_substring_in_persisted_data(description_secret)
    end

    it "returns errors when submission is invalid" do
      submission = Intake::CaseSubmission.new(title: "", sources: [])

      result = described_class.call(user: user, submission: submission)

      expect(result).not_to be_success
      expect(result.debugging_case).to be_nil
      expect(result.errors[:title]).to include("can't be blank")
      expect(result.errors[:sources]).to include("must include at least one non-blank log source")
      expect(DebuggingCase.count).to eq(0)
    end

    it "skips sources with blank pasted content" do
      submission = build_submission(
        sources: [
          { source_type: "rails_log", pasted_content: "request_id=req-only-1" },
          { source_type: "other", pasted_content: "" },
          { source_type: "other", pasted_content: "   " }
        ]
      )

      result = described_class.call(user: user, submission: submission)

      expect(result).to be_success
      expect(result.debugging_case.log_sources.count).to eq(1)
    end
  end
end
