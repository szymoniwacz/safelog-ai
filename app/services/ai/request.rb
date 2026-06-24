# frozen_string_literal: true

module Ai
  # Outbound AI request envelope. Sanitization is enforced upstream: only
  # Analysis::PromptBuilder (and future callers) may construct messages, and
  # those services must use redacted/sanitized case evidence only. This class
  # validates request shape, blocks forbidden metadata keys, and applies a
  # lightweight defense-in-depth content guard for obvious raw-secret shapes
  # (Bearer tokens, unredacted emails). Placeholder tokens such as [EMAIL_1]
  # are allowed.
  class Request
    FORBIDDEN_KEY_PATTERN = /raw|original|mapping/i
    BEARER_TOKEN_PATTERN = /Authorization:\s*Bearer\s+\S+/i
    RAW_EMAIL_PATTERN = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/

    attr_reader :messages, :case_ref

    def initialize(messages:, case_ref: nil, metadata: {})
      validate_messages!(messages)
      validate_metadata!(metadata)

      @messages = messages.map { |message| normalize_message(message) }
      @case_ref = case_ref
    end

    private

    def validate_messages!(messages)
      unless messages.is_a?(Array) && messages.any?
        raise ArgumentError, "messages must be a non-empty array"
      end

      messages.each do |message|
        unless message.is_a?(Hash) && message[:role].is_a?(String) && message[:content].is_a?(String)
          raise ArgumentError, "each message must have string role and content"
        end

        validate_message_content!(message[:content])
      end
    end

    def validate_message_content!(content)
      if content.match?(BEARER_TOKEN_PATTERN)
        raise ArgumentError, "message content must not contain raw Authorization Bearer tokens"
      end

      if content.match?(RAW_EMAIL_PATTERN)
        raise ArgumentError, "message content must not contain raw email addresses"
      end
    end

    def validate_metadata!(metadata)
      metadata.each_key do |key|
        if key.to_s.match?(FORBIDDEN_KEY_PATTERN)
          raise ArgumentError, "metadata key #{key.inspect} is not allowed"
        end
      end
    end

    def normalize_message(message)
      { role: message[:role], content: message[:content] }
    end
  end
end
