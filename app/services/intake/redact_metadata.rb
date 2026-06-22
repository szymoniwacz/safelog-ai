# frozen_string_literal: true

module Intake
  class RedactMetadata
    def self.call(text, registry:)
      new(registry: registry).call(text)
    end

    def initialize(registry:)
      @registry = registry
    end

    def call(text)
      return if text.blank?

      Redaction::Engine.redact(text, registry: @registry).sanitized_text
    end
  end
end
