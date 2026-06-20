# frozen_string_literal: true

require "rails_helper"

RSpec.describe Redaction::Finding do
  describe ".new" do
    it "accepts the four required attributes" do
      finding = described_class.new(
        finding_type: "email",
        line_number: 1,
        placeholder: "[EMAIL_1]",
        risk_level: "high"
      )

      expect(finding.finding_type).to eq("email")
      expect(finding.line_number).to eq(1)
      expect(finding.placeholder).to eq("[EMAIL_1]")
      expect(finding.risk_level).to eq("high")
    end

    it "rejects unknown keyword arguments" do
      expect do
        described_class.new(
          finding_type: "email",
          line_number: 1,
          placeholder: "[EMAIL_1]",
          risk_level: "high",
          original: "secret@example.com"
        )
      end.to raise_error(ArgumentError, /unknown keyword/)
    end

    it "rejects blank attributes" do
      expect do
        described_class.new(
          finding_type: "",
          line_number: 1,
          placeholder: "[EMAIL_1]",
          risk_level: "high"
        )
      end.to raise_error(ArgumentError, /finding_type must be present/)
    end
  end
end
