# frozen_string_literal: true

module Ai
  class OpenAiClient
    include Client

    CHAT_COMPLETIONS_URL = "https://api.openai.com/v1/chat/completions"

    def initialize(api_key: ENV["OPENAI_API_KEY"], model: ENV.fetch("OPENAI_MODEL", "gpt-4o-mini"), client: nil)
      if api_key.blank?
        raise ArgumentError, "OPENAI_API_KEY is required"
      end

      @model = model
      @client = client || OpenAI::Client.new(access_token: api_key)
    end

    def complete(request)
      response = @client.chat(parameters: chat_parameters(request))
      structured, markdown = extract_completion_payload(response)
      validated = ResponseValidator.call(structured)

      CompletionResult.new(
        structured: validated.structured,
        markdown: markdown
      )
    end

    private

    def chat_parameters(request)
      {
        model: @model,
        messages: request.messages.map { |message| { role: message[:role], content: message[:content] } },
        response_format: { type: "json_object" }
      }
    end

    def extract_completion_payload(response)
      content = response.dig("choices", 0, "message", "content")
      if content.blank?
        raise InvalidResponseError, "assistant response was empty"
      end

      payload = JSON.parse(content)
      unless payload.is_a?(Hash) && payload.key?("structured") && payload.key?("markdown")
        raise InvalidResponseError, "assistant response must include structured and markdown"
      end

      markdown = payload["markdown"]
      unless markdown.is_a?(String) && markdown.strip.present?
        raise InvalidResponseError, "markdown must be a non-empty string"
      end

      [ payload["structured"], markdown ]
    rescue JSON::ParserError
      raise InvalidResponseError, "assistant response was not valid JSON"
    end
  end
end
