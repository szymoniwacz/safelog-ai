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

    it "treats nil sources as an empty list and fails validation" do
      submission = described_class.new(title: "Checkout timeout", sources: nil)

      expect(submission).not_to be_valid
      expect(submission.errors[:sources]).to include("must include at least one non-blank log source")
      expect(submission.sources).to eq([])
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

    it "reports the UI slot number for invalid source types when earlier slots are blank" do
      submission = described_class.new(
        title: "Checkout timeout",
        sources: [
          { source_type: "rails_log", pasted_content: "" },
          { source_type: "invalid_type", pasted_content: "session_id=sess-2" }
        ]
      )

      expect(submission).not_to be_valid
      expect(submission.errors[:sources].first).to include("source 2 has an invalid source type")
    end

    it "reports each UI slot number when multiple sources have invalid types" do
      submission = described_class.new(
        title: "Checkout timeout",
        sources: [
          { source_type: "invalid_type", pasted_content: "session_id=sess-1" },
          { source_type: "rails_log", pasted_content: "request_id=req-1" },
          { source_type: "bad_type", pasted_content: "console error" }
        ]
      )

      expect(submission).not_to be_valid
      expect(submission.errors[:sources]).to include("source 1 has an invalid source type")
      expect(submission.errors[:sources]).to include("source 3 has an invalid source type")
    end
  end
end
