# frozen_string_literal: true

require "rails_helper"

RSpec.describe RedactionFinding do
  describe ".build_from_engine_finding" do
    let(:finding) do
      Redaction::Finding.new(
        finding_type: "email",
        line_number: 3,
        placeholder: "[EMAIL_1]",
        risk_level: "high"
      )
    end

    it "maps a Finding to persistence attributes" do
      attributes = described_class.build_from_engine_finding(finding)

      expect(attributes).to eq(
        finding_type: "email",
        line_number: 3,
        placeholder: "[EMAIL_1]",
        risk_level: "high"
      )
    end

    it "returns only assignable AR attribute keys" do
      attributes = described_class.build_from_engine_finding(finding)

      expect(attributes.keys).to match_array(described_class::PERSISTED_ATTRIBUTES)
    end

    it "raises ArgumentError for a Hash" do
      expect do
        described_class.build_from_engine_finding(
          {
            finding_type: "email",
            line_number: 1,
            placeholder: "[EMAIL_1]",
            risk_level: "high"
          }
        )
      end.to raise_error(ArgumentError, /expected Redaction::Finding/)
    end

    it "raises ArgumentError for other types" do
      expect do
        described_class.build_from_engine_finding("not a finding")
      end.to raise_error(ArgumentError, /expected Redaction::Finding/)
    end
  end
end
