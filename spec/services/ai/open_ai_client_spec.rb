# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::OpenAiClient do
  subject(:client) { described_class.new(api_key: "test-key", client: openai_client) }

  let(:openai_client) { instance_double(OpenAI::Client) }
  let(:request) do
    Ai::Request.new(
      messages: [ { role: "user", content: "Analyze sanitized evidence for [REQUEST_1]." } ]
    )
  end
  let(:structured) { Ai::ReportSchema.canonical_structured }
  let(:markdown) { "## Hypothesis report\n\nSanitized summary." }
  let(:assistant_content) do
    {
      structured: structured,
      markdown: markdown
    }.to_json
  end
  let(:chat_response) do
    {
      "choices" => [
        {
          "message" => {
            "content" => assistant_content
          }
        }
      ]
    }
  end

  before do
    allow(openai_client).to receive(:chat).and_return(chat_response)
  end

  describe "#initialize" do
    it "requires an API key" do
      expect { described_class.new(api_key: nil) }.to raise_error(ArgumentError, /OPENAI_API_KEY/)
    end
  end

  describe "#complete" do
    it "maps assistant JSON into a validated completion result" do
      result = client.complete(request)

      expect(openai_client).to have_received(:chat).with(
        parameters: hash_including(
          model: "gpt-4o-mini",
          messages: [ { role: "user", content: "Analyze sanitized evidence for [REQUEST_1]." } ],
          response_format: { type: "json_object" }
        )
      )
      expect(result.structured).to eq(structured)
      expect(result.markdown).to eq(markdown)
    end
  end

  describe "HTTP integration", :openai_http do
    it "uses the OpenAI chat completions endpoint without real network access" do
      stub_request(:post, Ai::OpenAiClient::CHAT_COMPLETIONS_URL)
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: chat_response.to_json
        )

      real_style_client = described_class.new(api_key: "dummy")
      result = real_style_client.complete(request)

      expect(result.markdown).to eq(markdown)
      expect(WebMock).to have_requested(:post, Ai::OpenAiClient::CHAT_COMPLETIONS_URL).once
    end
  end
end
