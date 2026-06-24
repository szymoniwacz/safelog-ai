# frozen_string_literal: true

require "rails_helper"

RSpec.describe Redaction::Engine do
  describe ".redact" do
    it "returns empty sanitized text and no findings for nil input" do
      result = described_class.redact(nil)

      expect(result.sanitized_text).to eq("")
      expect(result.findings).to eq([])
    end

    it "returns empty sanitized text and no findings for empty input" do
      result = described_class.redact("")

      expect(result.sanitized_text).to eq("")
      expect(result.findings).to eq([])
    end

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
        have_attributes(
          finding_type: "email",
          line_number: 1,
          placeholder: "[EMAIL_1]",
          risk_level: "high"
        ),
        have_attributes(
          finding_type: "authorization_header",
          line_number: 2,
          placeholder: "[AUTH_1]",
          risk_level: "high"
        )
      )

      result.findings.each do |finding|
        expect(finding).to be_a(Redaction::Finding)
        expect(finding.members).not_to include(:original, :raw)
        expect([ finding.finding_type, finding.line_number.to_s, finding.placeholder, finding.risk_level ].join)
          .not_to include("user@example.com")
        expect([ finding.finding_type, finding.line_number.to_s, finding.placeholder, finding.risk_level ].join)
          .not_to include("sk-test-token-abcdef123456")
      end
    end

    it "normalizes Windows CRLF line endings before redaction" do
      raw = "User login failed for user@example.com\r\nAuthorization: Bearer sk-test-token-abcdef123456"

      result = described_class.redact(raw)

      expect(result.sanitized_text).not_to include("\r")
      expect(result.sanitized_text).to eq(<<~SANITIZED.chomp)
        User login failed for [EMAIL_1]
        [AUTH_1]
      SANITIZED
    end

    it "redacts multiple patterns on a single line" do
      raw = "User user@example.com failed token=supersecretkey12345678"

      result = described_class.redact(raw)

      expect(result.sanitized_text).to include("[EMAIL_1]")
      expect(result.sanitized_text).to include("[TOKEN_1]")
      expect(result.sanitized_text).not_to include("user@example.com")
      expect(result.sanitized_text).not_to include("supersecretkey12345678")

      expect(result.findings).to contain_exactly(
        have_attributes(
          finding_type: "email",
          line_number: 1,
          placeholder: "[EMAIL_1]",
          risk_level: "high"
        ),
        have_attributes(
          finding_type: "token",
          line_number: 1,
          placeholder: "[TOKEN_1]",
          risk_level: "high"
        )
      )
    end

    it "records line numbers from the original text" do
      raw = <<~LOG.strip
        ok line
        request_id=req-shared-999
      LOG

      result = described_class.redact(raw)

      expect(result.findings).to include(
        have_attributes(
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
      expect(first.findings.first.placeholder).to eq(second.findings.first.placeholder)
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
