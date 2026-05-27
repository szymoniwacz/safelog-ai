# frozen_string_literal: true

module Ai
  class Request
    FORBIDDEN_KEY_PATTERN = /raw|original|mapping/i

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
