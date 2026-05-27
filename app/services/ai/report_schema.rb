# frozen_string_literal: true

module Ai
  # Hypothesis-framed AI report JSON contract (PRD guardrails: hypotheses + uncertainty).
  #
  # Required top-level keys:
  # - summary (String)
  # - hypotheses (Array<Hash>) each with title, description; optional confidence
  # - uncertainty_notes (Array<String>, min 1)
  #
  # Optional:
  # - correlation_highlights (Array<String>)
  class ReportSchema
    REQUIRED_KEYS = %i[summary hypotheses uncertainty_notes].freeze
    HYPOTHESIS_REQUIRED_KEYS = %i[title description].freeze

    CANONICAL_STRUCTURED = {
      summary: "Checkout timeout may be caused by downstream payment latency.",
      hypotheses: [
        {
          title: "Payment gateway timeout",
          description: "Requests to [REQUEST_1] exceeded the configured timeout while waiting for authorization."
        }
      ],
      uncertainty_notes: [
        "This report is based on sanitized evidence only and does not confirm production root cause."
      ],
      correlation_highlights: [
        "[REQUEST_1] appears in both application and gateway logs."
      ]
    }.freeze

    CANONICAL_MARKDOWN = <<~MARKDOWN.freeze
      ## Hypothesis report

      Checkout timeout may be caused by downstream payment latency.

      ### Hypotheses

      1. **Payment gateway timeout** — Requests to [REQUEST_1] exceeded the configured timeout while waiting for authorization.

      ### Uncertainty

      - This report is based on sanitized evidence only and does not confirm production root cause.
    MARKDOWN

    def self.canonical_structured
      CANONICAL_STRUCTURED
    end

    def self.canonical_markdown
      CANONICAL_MARKDOWN
    end
  end
end
