# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analysis::ReportFilename do
  let(:user) { create(:user) }

  def build_case(title:)
    Intake::ProcessCaseSubmission.call(
      user: user,
      submission: Intake::CaseSubmission.new(
        title: title,
        sources: [ { source_type: "rails_log", pasted_content: "ok" } ]
      )
    ).debugging_case
  end

  describe ".call" do
    it "parameterizes the case title with a report suffix" do
      debugging_case = build_case(title: "Checkout Timeout")

      expect(described_class.call(debugging_case: debugging_case)).to eq("checkout-timeout-report.md")
    end

    it "falls back to the case id when title parameterizes to blank" do
      debugging_case = build_case(title: "---")

      expect(described_class.call(debugging_case: debugging_case)).to eq("debugging-case-#{debugging_case.id}-report.md")
    end
  end
end
