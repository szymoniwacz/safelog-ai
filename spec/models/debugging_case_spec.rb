# frozen_string_literal: true

require "rails_helper"

RSpec.describe DebuggingCase, type: :model do
  let(:user) { create(:user) }

  def create_case(title: "Scope test case")
    Intake::ProcessCaseSubmission.call(
      user: user,
      submission: Intake::CaseSubmission.new(
        title: title,
        sources: [ { source_type: "rails_log", pasted_content: "ok" } ]
      )
    ).debugging_case
  end

  describe "scopes" do
    it "separates active and archived cases" do
      active_case = create_case(title: "Active case")
      archived_case = create_case(title: "Archived case")
      archived_case.archive!

      expect(described_class.active).to contain_exactly(active_case)
      expect(described_class.archived).to contain_exactly(archived_case)
    end
  end

  describe "#archive!" do
    it "sets archived_at once" do
      debugging_case = create_case

      debugging_case.archive!
      expect(debugging_case.archived_at).to be_present

      original_timestamp = debugging_case.archived_at
      debugging_case.archive!
      expect(debugging_case.reload.archived_at).to eq(original_timestamp)
    end
  end

  describe "#analysis_status" do
    it "returns not_analyzed when the case has no AI reports" do
      debugging_case = create_case

      expect(debugging_case.analysis_status).to eq(:not_analyzed)
    end

    it "returns analyzed when the latest report is generated" do
      debugging_case = create_case
      debugging_case.ai_reports.create!(status: :generated, markdown_body: "# Report")

      expect(debugging_case.analysis_status).to eq(:analyzed)
    end

    it "returns failed when the latest report failed" do
      debugging_case = create_case
      debugging_case.ai_reports.create!(status: :failed)

      expect(debugging_case.analysis_status).to eq(:failed)
    end

    it "uses the most recent report when multiple exist" do
      debugging_case = create_case
      debugging_case.ai_reports.create!(status: :generated, created_at: 2.hours.ago, markdown_body: "# Old")
      debugging_case.ai_reports.create!(status: :failed, created_at: 1.hour.ago)

      expect(debugging_case.analysis_status).to eq(:failed)
    end
  end
end
