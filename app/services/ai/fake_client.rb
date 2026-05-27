# frozen_string_literal: true

module Ai
  class FakeClient
    include Client

    attr_reader :last_request

    def complete(request)
      @last_request = request

      structured = ReportSchema.canonical_structured
      ResponseValidator.call(structured)

      CompletionResult.new(
        structured: structured,
        markdown: ReportSchema.canonical_markdown
      )
    end
  end
end
