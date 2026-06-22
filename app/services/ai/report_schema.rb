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
      summary: "Test case hypothesis report",
      hypotheses: [
        {
          title: "Test case hypothesis",
          description: "This is a test case hypothesis."
        }
      ],
      uncertainty_notes: [
        "This report is based on sanitized evidence only and does not confirm production root cause."
      ]
    }.freeze

    CANONICAL_MARKDOWN = <<~MARKDOWN.freeze
      ## Hypothesis report

      Test case hypothesis report

      ### Hypotheses

      1. **Test case hypothesis** — This is a test case hypothesis.

      ### Uncertainty

      - This is a test case uncertainty note.
    MARKDOWN

    def self.canonical_structured
      CANONICAL_STRUCTURED
    end

    def self.canonical_markdown
      CANONICAL_MARKDOWN
    end
  end
end
