# frozen_string_literal: true

require "rails_helper"

RSpec.describe Redaction::PlaceholderRegistry do
  subject(:registry) { described_class.new }

  it "allocates incrementing placeholders per type" do
    first = registry.placeholder_for(type: "EMAIL", value: "a@example.com")
    second = registry.placeholder_for(type: "EMAIL", value: "b@example.com")

    expect(first).to eq("[EMAIL_1]")
    expect(second).to eq("[EMAIL_2]")
  end

  it "reuses placeholders for the same normalized value and type" do
    first = registry.placeholder_for(type: "REQUEST", value: "req-abc-123")
    second = registry.placeholder_for(type: "REQUEST", value: "  req-abc-123  ")

    expect(first).to eq(second)
    expect(first).to eq("[REQUEST_1]")
  end

  it "uses different placeholders for the same value across types" do
    email = registry.placeholder_for(type: "EMAIL", value: "shared-value")
    request = registry.placeholder_for(type: "REQUEST", value: "shared-value")

    expect(email).to eq("[EMAIL_1]")
    expect(request).to eq("[REQUEST_1]")
  end
end
