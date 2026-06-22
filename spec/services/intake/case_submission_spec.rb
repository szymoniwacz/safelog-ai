# frozen_string_literal: true

require "rails_helper"

RSpec.describe Intake::CaseSubmission do
  describe "source normalization" do
    it "builds Source structs from symbol-key hashes" do
      submission = described_class.new(
        title: "Checkout timeout",
        sources: [
          {
            source_type: "rails_log",
            name: " Rails ",
            pasted_content: " request_id=req-1 "
          }
        ]
      )

      source = submission.sources.first

      expect(source).to be_a(described_class::Source)
      expect(source.source_type).to eq("rails_log")
      expect(source.name).to eq("Rails")
      expect(source.pasted_content).to eq("request_id=req-1")
    end

    it "builds Source structs from string-key hashes" do
      submission = described_class.new(
        title: "Checkout timeout",
        sources: [
          {
            "source_type" => "browser_console",
            "name" => "Browser",
            "pasted_content" => "console error"
          }
        ]
      )

      source = submission.sources.first

      expect(source.source_type).to eq("browser_console")
      expect(source.name).to eq("Browser")
      expect(source.pasted_content).to eq("console error")
    end
  end

  describe "validations" do
    it "requires at least one non-blank log source" do
      submission = described_class.new(title: "Checkout timeout", sources: [])

      expect(submission).not_to be_valid
      expect(submission.errors[:sources]).to include("must include at least one non-blank log source")
    end

    it "rejects invalid source types" do
      submission = described_class.new(
        title: "Checkout timeout",
        sources: [
          { source_type: "invalid_type", pasted_content: "session_id=sess-1" }
        ]
      )

      expect(submission).not_to be_valid
      expect(submission.errors[:sources].first).to include("invalid source type")
    end
  end
end
