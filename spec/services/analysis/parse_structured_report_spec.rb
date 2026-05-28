# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analysis::ParseStructuredReport do
  let(:user) { create(:user) }

  def build_report(structured_json)
    debugging_case = Intake::ProcessCaseSubmission.call(
      user: user,
      submission: Intake::CaseSubmission.new(
        title: "Structured report case",
        sources: [ { source_type: "rails_log", pasted_content: "ok" } ]
      )
    ).debugging_case

    debugging_case.ai_reports.create!(
      status: :generated,
      structured_json: structured_json,
      markdown_body: "# Report"
    )
  end

  describe ".call" do
    it "returns parsed structured JSON" do
      report = build_report({ summary: "Timeout during checkout" }.to_json)

      expect(described_class.call(ai_report: report)).to eq("summary" => "Timeout during checkout")
    end

    it "returns nil when structured_json is blank" do
      report = build_report(nil)

      expect(described_class.call(ai_report: report)).to be_nil
    end

    it "returns nil when structured_json is invalid" do
      report = build_report("{not-json")

      expect(described_class.call(ai_report: report)).to be_nil
    end
  end
end
