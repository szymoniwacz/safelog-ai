# frozen_string_literal: true

require "rails_helper"

RSpec.describe Redaction::Engine do
  describe ".redact" do
    it "redacts emails and authorization headers without storing originals in findings" do
      raw = <<~LOG.strip
        User login failed for user@example.com
        Authorization: Bearer sk-test-token-abcdef123456
      LOG

      result = described_class.redact(raw)

      expect(result.sanitized_text).to include("[EMAIL_1]")
      expect(result.sanitized_text).to include("[AUTH_1]")
      expect(result.sanitized_text).not_to include("user@example.com")
      expect(result.sanitized_text).not_to include("sk-test-token-abcdef123456")

      expect(result.findings).to contain_exactly(
        hash_including(
          finding_type: "email",
          line_number: 1,
          placeholder: "[EMAIL_1]",
          risk_level: "high"
        ),
        hash_including(
          finding_type: "authorization_header",
          line_number: 2,
          placeholder: "[AUTH_1]",
          risk_level: "high"
        )
      )

      result.findings.each do |finding|
        expect(finding).not_to have_key(:original)
        expect(finding).not_to have_key(:raw)
        expect(finding.values.join).not_to include("user@example.com")
        expect(finding.values.join).not_to include("sk-test-token-abcdef123456")
      end
    end

    it "records line numbers from the original text" do
      raw = <<~LOG.strip
        ok line
        request_id=req-shared-999
      LOG

      result = described_class.redact(raw)

      expect(result.findings).to include(
        hash_including(
          finding_type: "request_id",
          line_number: 2,
          placeholder: "[REQUEST_1]"
        )
      )
    end

    it "reuses placeholders across redactions with a shared registry" do
      registry = Redaction::PlaceholderRegistry.new
      first = described_class.redact("request_id=req-shared-999", registry: registry)
      second = described_class.redact("request_id=req-shared-999", registry: registry)

      expect(first.sanitized_text).to include("[REQUEST_1]")
      expect(second.sanitized_text).to include("[REQUEST_1]")
      expect(first.findings.first[:placeholder]).to eq(second.findings.first[:placeholder])
    end

    it "correlates the same request id across two sources in one submission" do
      registry = Redaction::PlaceholderRegistry.new

      rails_log = described_class.redact(
        "Started GET /checkout request_id=req-shared-999",
        registry: registry
      )
      cloudwatch = described_class.redact(
        "Timeout waiting for request_id=req-shared-999",
        registry: registry
      )

      expect(rails_log.sanitized_text).to include("[REQUEST_1]")
      expect(cloudwatch.sanitized_text).to include("[REQUEST_1]")
    end
  end
end
