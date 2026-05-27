# frozen_string_literal: true

require "rails_helper"

RSpec.describe "AGENTS.md AI guardrails" do
  describe "CI isolation" do
    it "uses FakeClient in test so real providers are never called" do
      expect(Ai::ClientResolver.current).to be_a(Ai::FakeClient)
    end

    it "blocks external HTTP in the test suite" do
      expect do
        Net::HTTP.get(URI("https://api.openai.com/v1/models"))
      end.to raise_error(WebMock::NetConnectNotAllowedError)
    end
  end

  describe "sanitized prompt boundary" do
    it "rejects forbidden raw-like metadata on AI requests" do
      expect do
        Ai::Request.new(
          messages: [ { role: "user", content: "Evidence with [EMAIL_1] only." } ],
          metadata: { raw_content: "must-not-send" }
        )
      end.to raise_error(ArgumentError, /not allowed/)
    end

    it "does not persist prompts via the fake client (in-memory last_request only)" do
      client = Ai::FakeClient.new
      request = Ai::Request.new(
        messages: [ { role: "user", content: "Sanitized evidence for [REQUEST_1]." } ]
      )

      client.complete(request)

      expect(client.last_request).to eq(request)
      expect(defined?(AiPrompt)).to be_nil
    end
  end
end
