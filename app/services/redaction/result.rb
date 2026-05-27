# frozen_string_literal: true

module Redaction
  class Result
    attr_reader :sanitized_text, :findings

    def initialize(sanitized_text:, findings:)
      @sanitized_text = sanitized_text
      @findings = findings
    end
  end
end
