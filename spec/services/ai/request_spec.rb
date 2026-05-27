# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::Request do
  describe "initialization" do
    it "accepts sanitized messages" do
      request = described_class.new(
        messages: [ { role: "user", content: "Error for [REQUEST_1] in checkout flow." } ],
        case_ref: "case-42"
      )

      expect(request.messages).to eq([ { role: "user", content: "Error for [REQUEST_1] in checkout flow." } ])
      expect(request.case_ref).to eq("case-42")
    end

    it "rejects empty messages" do
      expect do
        described_class.new(messages: [])
      end.to raise_error(ArgumentError, /non-empty array/)
    end

    it "rejects non-string message content" do
      expect do
        described_class.new(messages: [ { role: "user", content: 123 } ])
      end.to raise_error(ArgumentError, /string role and content/)
    end

    it "rejects forbidden metadata keys" do
      expect do
        described_class.new(
          messages: [ { role: "user", content: "Sanitized evidence only." } ],
          metadata: { raw_content: "secret" }
        )
      end.to raise_error(ArgumentError, /not allowed/)
    end
  end
end
