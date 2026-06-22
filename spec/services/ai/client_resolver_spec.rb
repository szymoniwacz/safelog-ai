# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::ClientResolver do
  describe ".current" do
    it "returns a fake client in test" do
      expect(described_class.current).to be_a(Ai::FakeClient)
    end

    it "returns an invalid client when E2E header mode is set" do
      Ai::E2eContext.client_mode = "invalid"

      client = described_class.current
      expect(client).to be_a(Ai::InvalidClient)

      request = Ai::Request.new(
        messages: [ { role: "user", content: "Sanitized evidence for [REQUEST_1]." } ]
      )
      result = client.complete(request)

      expect(client.complete_calls).to eq(1)
      expect(client.last_request).to eq(request)
      expect(result).to be_a(Ai::CompletionResult)
    ensure
      Ai::E2eContext.reset
    end
  end

  describe ".fake_client_active?" do
    it "is false in test so the UI notice stays out of request specs" do
      expect(described_class.fake_client_active?).to be(false)
    end

    context "outside test" do
      before do
        allow(Rails.env).to receive(:test?).and_return(false)
      end

      it "is true when OPENAI_API_KEY is blank" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return(nil)

        expect(described_class.fake_client_active?).to be(true)
      end

      it "is false when OPENAI_API_KEY is present" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("sk-test")

        expect(described_class.fake_client_active?).to be(false)
      end
    end
  end

  describe ".current outside test" do
    before do
      allow(Rails.env).to receive(:test?).and_return(false)
    end

    it "returns OpenAiClient when OPENAI_API_KEY is present" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("sk-test")

      expect(described_class.current).to be_a(Ai::OpenAiClient)
    end

    it "returns FakeClient when OPENAI_API_KEY is blank" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return(nil)

      expect(described_class.current).to be_a(Ai::FakeClient)
    end
  end
end
