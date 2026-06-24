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

      expect(debugging_case.log_sources.order(:position).pluck(:position)).to eq([0, 1])
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

    it "redacts secrets in environment metadata on persist" do
      environment_secret = "env-intake-#{SecureRandom.hex(4)}@secret.example"

      submission = build_submission(
        environment: "Contact #{environment_secret}",
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
      expect(debugging_case.environment).to include("[EMAIL_1]")
      expect(debugging_case.environment).not_to include(environment_secret)

      assert_no_raw_substring_in_persisted_data(environment_secret)
    end

    it "leaves blank environment unset on persist" do
      submission = build_submission(
        environment: nil,
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
      expect(result.debugging_case.environment).to be_blank
    end

    it "redacts secrets in source name on persist" do
      name_secret = "name-intake-#{SecureRandom.hex(4)}@secret.example"

      submission = build_submission(
        sources: [
          {
            source_type: "rails_log",
            name: "Reporter #{name_secret}",
            pasted_content: "Started GET /health"
          }
        ]
      )

      result = described_class.call(user: user, submission: submission)
      expect(result).to be_success

      log_source = result.debugging_case.log_sources.first
      expect(log_source.name).to include("[EMAIL_1]")
      expect(log_source.name).not_to include(name_secret)

      assert_no_raw_substring_in_persisted_data(name_secret)
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
      expect(result.debugging_case).to be_nil
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

    it "returns errors when source type is invalid" do
      submission = build_submission(
        sources: [
          { source_type: "invalid_type", pasted_content: "session_id=sess-invalid-1" }
        ]
      )

      result = described_class.call(user: user, submission: submission)

      expect(result).not_to be_success
      expect(result.debugging_case).to be_nil
      expect(result.errors[:sources].first).to include("invalid source type")
    end

    it "returns ActiveRecord errors when persistence fails inside the transaction" do
      submission = build_submission
      invalid_record = DebuggingCase.new
      invalid_record.errors.add(:title, "forced failure")

      cases_relation = user.debugging_cases
      allow(user).to receive(:debugging_cases).and_return(cases_relation)
      allow(cases_relation).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(invalid_record))

      result = described_class.call(user: user, submission: submission)

      expect(result).not_to be_success
      expect(result.debugging_case).to be_nil
      expect(result.errors[:title]).to include("forced failure")
    end

    it "returns ActiveRecord errors when PersistRedactedCase raises RecordInvalid" do
      submission = build_submission
      invalid_record = LogSource.new
      invalid_record.errors.add(:sanitized_content, "forced persist failure")

      allow(Intake::PersistRedactedCase).to receive(:call).and_raise(
        ActiveRecord::RecordInvalid.new(invalid_record)
      )

      result = described_class.call(user: user, submission: submission)

      expect(result).not_to be_success
      expect(result.debugging_case).to be_nil
      expect(result.errors[:sanitized_content]).to include("forced persist failure")
    end

    it "redacts all PRD MVP pattern types on persist" do
      session_secret = "sess-redact-#{SecureRandom.hex(4)}"
      customer_secret = "cust-redact-#{SecureRandom.hex(4)}"
      ip_secret = "10.20.30.#{rand(40..199)}"
      phone_secret = "555867#{rand(1000..9999)}"
      card_secret = "9876"
      token_secret = "supersecretkey#{SecureRandom.hex(6)}"

      submission = build_submission(
        sources: [
          {
            source_type: "rails_log",
            pasted_content: <<~LOG.strip
              session_id=#{session_secret}
              customer_id=#{customer_secret}
              upstream #{ip_secret}
              callback phone (#{phone_secret[0..2]}) #{phone_secret[3..5]}-#{phone_secret[6..9]}
              card ending #{card_secret}
              api_key=#{token_secret}
            LOG
          }
        ]
      )

      result = described_class.call(user: user, submission: submission)
      expect(result).to be_success

      sanitized = result.debugging_case.log_sources.first.sanitized_content
      finding_types = result.debugging_case.log_sources.flat_map(&:redaction_findings).map(&:finding_type)

      expect(sanitized).to include("[SESSION_1]")
      expect(sanitized).to include("[CUSTOMER_1]")
      expect(sanitized).to include("[IP_1]")
      expect(sanitized).to include("[PHONE_1]")
      expect(sanitized).to include("[CARD_1]")
      expect(sanitized).to include("[TOKEN_1]")
      expect(sanitized).not_to include(session_secret)
      expect(sanitized).not_to include(customer_secret)
      expect(sanitized).not_to include(ip_secret)
      expect(sanitized).not_to include(card_secret)
      expect(sanitized).not_to include(token_secret)

      expect(finding_types).to include(
        "session_id", "customer_id", "ip_address", "phone", "card_last4", "token"
      )

      assert_no_raw_substring_in_persisted_data(session_secret)
      assert_no_raw_substring_in_persisted_data(customer_secret)
      assert_no_raw_substring_in_persisted_data(ip_secret)
      assert_no_raw_substring_in_persisted_data(token_secret)
    end
  end
end
