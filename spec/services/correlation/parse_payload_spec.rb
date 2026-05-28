# frozen_string_literal: true

require "rails_helper"

RSpec.describe Correlation::ParsePayload do
  let(:user) { create(:user) }

  def build_signal(payload_json)
    debugging_case = Intake::ProcessCaseSubmission.call(
      user: user,
      submission: Intake::CaseSubmission.new(
        title: "Parse payload case",
        sources: [ { source_type: "rails_log", pasted_content: "ok" } ]
      )
    ).debugging_case

    debugging_case.correlation_signals.create!(payload: payload_json)
  end

  describe ".call" do
    it "returns signals from a valid payload" do
      signal = build_signal({ signals: [ { placeholder: "[REQUEST_1]", occurrence_count: 2 } ] }.to_json)

      result = described_class.call(correlation_signal: signal)

      expect(result).to eq([ { "placeholder" => "[REQUEST_1]", "occurrence_count" => 2 } ])
    end

    it "returns an empty array when payload is blank" do
      expect(described_class.call(correlation_signal: nil)).to eq([])
    end

    it "returns an empty array when payload is invalid JSON" do
      signal = build_signal("{not-json")

      expect(described_class.call(correlation_signal: signal)).to eq([])
    end
  end
end
