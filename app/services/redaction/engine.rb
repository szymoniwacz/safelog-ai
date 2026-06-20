# frozen_string_literal: true

module Redaction
  class Engine
    def self.redact(text, registry: PlaceholderRegistry.new)
      new(registry: registry).redact(text)
    end

    def initialize(registry:)
      @registry = registry
    end

    def redact(text)
      findings = []
      sanitized_lines = text.to_s.split(/\n/, -1).each_with_index.map do |line, index|
        redact_line(line, index + 1, findings)
      end

      Result.new(
        sanitized_text: sanitized_lines.join("\n"),
        findings: findings
      )
    end

    private

    def redact_line(line, line_number, findings)
      Patterns::ALL.reduce(line) do |current_line, pattern|
        current_line.gsub(pattern[:regex]) do |match|
          correlation_value = Regexp.last_match(1) || match
          placeholder = @registry.placeholder_for(
            type: pattern[:placeholder_type],
            value: correlation_value
          )

          findings << Finding.new(
            finding_type: pattern[:finding_type],
            line_number: line_number,
            placeholder: placeholder,
            risk_level: pattern[:risk_level]
          )

          placeholder
        end
      end
    end
  end
end
