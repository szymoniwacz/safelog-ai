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

    it "rejects non-array messages" do
      expect do
        described_class.new(messages: "not-an-array")
      end.to raise_error(ArgumentError, /non-empty array/)
    end

    it "rejects non-hash messages" do
      expect do
        described_class.new(messages: [ "not-a-hash" ])
      end.to raise_error(ArgumentError, /string role and content/)
    end

    it "rejects non-string message roles" do
      expect do
        described_class.new(messages: [ { role: :user, content: "Sanitized evidence only." } ])
      end.to raise_error(ArgumentError, /string role and content/)
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

    it "rejects metadata keys matching original or mapping patterns" do
      expect do
        described_class.new(
          messages: [ { role: "user", content: "Sanitized evidence only." } ],
          metadata: { original_payload: "secret", placeholder_mapping: "secret" }
        )
      end.to raise_error(ArgumentError, /not allowed/)
    end

    it "accepts allowed metadata keys" do
      request = described_class.new(
        messages: [ { role: "user", content: "Sanitized evidence only." } ],
        metadata: { case_id: "42" }
      )

      expect(request.messages).to eq([ { role: "user", content: "Sanitized evidence only." } ])
    end

    it "accepts placeholder tokens instead of raw emails" do
      request = described_class.new(
        messages: [ { role: "user", content: "Login failed for [EMAIL_1] in checkout." } ]
      )

      expect(request.messages.first[:content]).to include("[EMAIL_1]")
    end

    it "rejects raw Authorization Bearer tokens in message content" do
      expect do
        described_class.new(
          messages: [ { role: "user", content: "Authorization: Bearer sk-test-secret-token" } ]
        )
      end.to raise_error(ArgumentError, /raw Authorization Bearer tokens/)
    end

    it "rejects raw email addresses in message content" do
      expect do
        described_class.new(
          messages: [ { role: "user", content: "Login failed for user@example.com" } ]
        )
      end.to raise_error(ArgumentError, /raw email addresses/)
    end
  end
end
