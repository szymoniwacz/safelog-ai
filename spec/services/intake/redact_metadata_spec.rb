# frozen_string_literal: true

require "rails_helper"

RSpec.describe Intake::RedactMetadata do
  let(:registry) { Redaction::PlaceholderRegistry.new }

  describe ".call" do
    it "returns nil for nil text" do
      expect(described_class.call(nil, registry: registry)).to be_nil
    end

    it "returns nil for empty text" do
      # Legacy behavior: blank? early return yields nil, not "".
      expect(described_class.call("", registry: registry)).to be_nil
    end

    it "redacts secrets in metadata text" do
      secret_email = "meta-#{SecureRandom.hex(4)}@secret.example"

      result = described_class.call("Contact #{secret_email}", registry: registry)

      expect(result).to include("[EMAIL_1]")
      expect(result).not_to include(secret_email)
    end

    it "reuses placeholders across calls with the same registry" do
      shared_request_id = "req-shared-#{SecureRandom.hex(4)}"

      first = described_class.call("request_id=#{shared_request_id}", registry: registry)
      second = described_class.call("request_id=#{shared_request_id}", registry: registry)

      expect(first).to include("[REQUEST_1]")
      expect(second).to include("[REQUEST_1]")
    end
  end
end
