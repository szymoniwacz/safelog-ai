# frozen_string_literal: true

module Ai
  class FakeClient
    include Client

    FIXTURE_STRUCTURED = {
      summary: "Checkout timeout may be caused by downstream payment latency.",
      hypotheses: [
        {
          title: "Payment gateway timeout",
          description: "Requests to [REQUEST_1] exceeded the configured timeout while waiting for authorization."
        }
      ],
      uncertainty_notes: [
        "This report is based on sanitized evidence only and does not confirm production root cause."
      ]
    }.freeze

    FIXTURE_MARKDOWN = <<~MARKDOWN.freeze
      ## Hypothesis report

      Checkout timeout may be caused by downstream payment latency.

      ### Hypotheses

      1. **Payment gateway timeout** — Requests to [REQUEST_1] exceeded the configured timeout while waiting for authorization.

      ### Uncertainty

      - This report is based on sanitized evidence only and does not confirm production root cause.
    MARKDOWN

    attr_reader :last_request

    def complete(request)
      @last_request = request

      CompletionResult.new(
        structured: FIXTURE_STRUCTURED.dup,
        markdown: FIXTURE_MARKDOWN
      )
    end
  end
end
