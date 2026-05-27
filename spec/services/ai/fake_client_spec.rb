# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::FakeClient do
  subject(:client) { described_class.new }

  let(:request) do
    Ai::Request.new(
      messages: [ { role: "user", content: "Timeout for [REQUEST_1] during checkout." } ]
    )
  end

  describe "#complete" do
    it "returns deterministic structured and markdown output" do
      first = client.complete(request)
      second = described_class.new.complete(request)

      expect(first.structured).to eq(second.structured)
      expect(first.markdown).to eq(second.markdown)
      expect(first.structured[:hypotheses]).not_to be_empty
      expect(first.structured[:uncertainty_notes]).not_to be_empty
      expect { Ai::ResponseValidator.call(first.structured) }.not_to raise_error
    end

    it "records the last request in memory only" do
      client.complete(request)

      expect(client.last_request).to eq(request)
    end
  end
end
