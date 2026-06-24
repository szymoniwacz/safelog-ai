# frozen_string_literal: true

require "rails_helper"

RSpec.describe Redaction::Patterns do
  # Documents intentional MVP gaps in Patterns::ALL — extend patterns.rb when closing a gap.
  describe "standalone sk- API keys (MVP gap warning fixture)" do
    let(:standalone_key) { "sk-standalone-leak-abcdef123456" }

    it "does not redact a bare sk- key on its own line (known MVP gap)" do
      raw = standalone_key

      result = Redaction::Engine.redact(raw)

      expect(result.sanitized_text).to eq(standalone_key)
      expect(result.findings).to be_empty
    end

    it "redacts the same sk- key when labeled with token=" do
      raw = "token=#{standalone_key}"

      result = Redaction::Engine.redact(raw)

      expect(result.sanitized_text).to eq("[TOKEN_1]")
      expect(result.sanitized_text).not_to include(standalone_key)
      expect(result.sanitized_text).not_to include("token=")
      expect(result.findings).to contain_exactly(
        have_attributes(
          finding_type: "token",
          placeholder: "[TOKEN_1]",
          risk_level: "high"
        )
      )
    end
  end
end
