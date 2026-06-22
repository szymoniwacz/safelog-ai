# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::ResponseValidator do
  subject(:result) { described_class.call(structured) }

  let(:valid_structured) { Ai::ReportSchema::CANONICAL_STRUCTURED }

  context "with a valid fixture" do
    let(:structured) { valid_structured }

    it "returns a validation result with normalized structured data" do
      expect(result).to be_a(Ai::ResponseValidator::ValidationResult)
      expect(result.structured[:summary]).to eq(valid_structured[:summary])
      expect(result.structured[:hypotheses].size).to eq(1)
    end

    it "accepts string keys" do
      expect(described_class.call(JSON.parse(valid_structured.to_json))).to be_a(
        Ai::ResponseValidator::ValidationResult
      )
    end

    it "accepts structured payloads without correlation_highlights" do
      structured = valid_structured.except(:correlation_highlights)

      expect(described_class.call(structured)).to be_a(Ai::ResponseValidator::ValidationResult)
    end
  end

  context "with invalid payloads" do
    it "rejects nil" do
      expect { described_class.call(nil) }.to raise_error(
        Ai::InvalidResponseError,
        "structured response is required"
      )
    end

    it "rejects missing uncertainty_notes" do
      structured = valid_structured.except(:uncertainty_notes)

      expect { described_class.call(structured) }.to raise_error(
        Ai::InvalidResponseError,
        "structured response is missing required key"
      )
    end

    it "rejects empty hypotheses" do
      structured = valid_structured.merge(hypotheses: [])

      expect { described_class.call(structured) }.to raise_error(
        Ai::InvalidResponseError,
        "hypotheses must be a non-empty array"
      )
    end

    it "rejects hypotheses missing description" do
      structured = valid_structured.merge(
        hypotheses: [ { title: "Only a title" } ]
      )

      expect { described_class.call(structured) }.to raise_error(
        Ai::InvalidResponseError,
        "each hypothesis must include title and description"
      )
    end

    it "rejects non-string summary" do
      structured = valid_structured.merge(summary: 123)

      expect { described_class.call(structured) }.to raise_error(
        Ai::InvalidResponseError,
        "summary must be a non-empty string"
      )
    end

    it "rejects invalid correlation_highlights type" do
      structured = valid_structured.merge(correlation_highlights: "not-an-array")

      expect { described_class.call(structured) }.to raise_error(
        Ai::InvalidResponseError,
        "correlation_highlights must be an array when present"
      )
    end

    it "rejects non-hash structured payloads" do
      expect { described_class.call("not-a-hash") }.to raise_error(
        Ai::InvalidResponseError,
        "structured response must be a hash"
      )
    end

    it "rejects hypotheses that are not hashes" do
      structured = valid_structured.merge(hypotheses: [ "not-a-hash" ])

      expect { described_class.call(structured) }.to raise_error(
        Ai::InvalidResponseError,
        "each hypothesis must be a hash"
      )
    end

    it "rejects non-string hypothesis confidence when present" do
      structured = valid_structured.merge(
        hypotheses: [
          valid_structured[:hypotheses].first.merge(confidence: 0.9)
        ]
      )

      expect { described_class.call(structured) }.to raise_error(
        Ai::InvalidResponseError,
        "hypothesis confidence must be a string when present"
      )
    end

    it "rejects empty uncertainty_notes" do
      structured = valid_structured.merge(uncertainty_notes: [])

      expect { described_class.call(structured) }.to raise_error(
        Ai::InvalidResponseError,
        "uncertainty_notes must be a non-empty array"
      )
    end

    it "rejects blank uncertainty notes" do
      structured = valid_structured.merge(uncertainty_notes: [ "   " ])

      expect { described_class.call(structured) }.to raise_error(
        Ai::InvalidResponseError,
        "each uncertainty note must be a non-empty string"
      )
    end

    it "rejects blank correlation highlights" do
      structured = valid_structured.merge(correlation_highlights: [ "   " ])

      expect { described_class.call(structured) }.to raise_error(
        Ai::InvalidResponseError,
        "each correlation highlight must be a non-empty string"
      )
    end
  end
end
