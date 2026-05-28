# frozen_string_literal: true

module Analysis
  # Builds Ai::Request payloads from persisted sanitized evidence only.
  # Do not pass raw intake fields (pasted_content, pre-redaction metadata) here.
  class PromptBuilder
    def self.call(debugging_case:, correlation_payload:)
      new(debugging_case: debugging_case, correlation_payload: correlation_payload).call
    end

    def initialize(debugging_case:, correlation_payload:)
      @debugging_case = debugging_case
      @correlation_payload = correlation_payload
    end

    def call
      Ai::Request.new(
        messages: [
          { role: "system", content: system_message },
          { role: "user", content: user_message }
        ],
        case_ref: @debugging_case.id
      )
    end

    private

    def system_message
      <<~TEXT.strip
        You are a debugging assistant for SafeLog AI. Analyze sanitized log evidence only.
        Respond with hypothesis-framed conclusions, not certainty about production root cause.
        Use placeholder tokens exactly as provided (e.g. [REQUEST_1]).
      TEXT
    end

    def user_message
      sections = []
      sections << "Case title: #{@debugging_case.title}"
      sections << "Environment: #{@debugging_case.environment}" if @debugging_case.environment.present?
      if @debugging_case.customer_reference.present?
        sections << "Customer reference: #{@debugging_case.customer_reference}"
      end
      sections << "Description: #{@debugging_case.description}" if @debugging_case.description.present?
      sections << "Correlation signals:\n#{JSON.pretty_generate(@correlation_payload)}"

      @debugging_case.log_sources.order(:position).each_with_index do |source, index|
        label = source.name.presence || source.source_type.humanize
        sections << "Log source #{index + 1} (#{label}, #{source.source_type}):\n#{source.sanitized_content}"
      end

      sections.join("\n\n")
    end
  end
end
