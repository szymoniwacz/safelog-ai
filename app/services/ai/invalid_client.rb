# frozen_string_literal: true

module Ai
  class InvalidClient
    include Client

    attr_reader :complete_calls, :last_request

    def initialize
      @complete_calls = 0
    end

    def complete(request)
      @complete_calls += 1
      @last_request = request

      CompletionResult.new(structured: { summary: "" }, markdown: "")
    end
  end
end
