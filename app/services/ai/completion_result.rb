# frozen_string_literal: true

module Ai
  class CompletionResult
    attr_reader :structured, :markdown

    def initialize(structured:, markdown:)
      unless structured.is_a?(Hash)
        raise ArgumentError, "structured must be a hash"
      end

      unless markdown.is_a?(String)
        raise ArgumentError, "markdown must be a string"
      end

      @structured = structured
      @markdown = markdown
    end
  end
end
