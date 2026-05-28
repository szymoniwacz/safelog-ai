# frozen_string_literal: true

require "rails_helper"

RSpec.describe Redaction::SummaryCounts do
  let(:user) { create(:user) }

  def build_findings
    debugging_case = Intake::ProcessCaseSubmission.call(
      user: user,
      submission: Intake::CaseSubmission.new(
        title: "Summary counts case",
        sources: [
          {
            source_type: "rails_log",
            pasted_content: "User login failed for leak@secret.example\nAuthorization: Bearer sk-test-token-abcdef123456"
          }
        ]
      )
    ).debugging_case

    debugging_case.log_sources.flat_map(&:redaction_findings)
  end

  describe ".call" do
    it "groups findings by type and risk level" do
      findings = build_findings

      result = described_class.call(findings: findings)

      expect(result.values.sum).to eq(findings.size)
      expect(result.keys).to all(be_an(Array))
      expect(result.keys.map(&:first)).to include("email", "authorization_header")
    end

    it "returns an empty hash when there are no findings" do
      expect(described_class.call(findings: [])).to eq({})
    end
  end
end
