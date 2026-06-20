# frozen_string_literal: true

module Redaction
  class Result
    # @return [String]
    attr_reader :sanitized_text
    # @return [Array<Redaction::Finding>]
    attr_reader :findings

    def initialize(sanitized_text:, findings:)
      @sanitized_text = sanitized_text
      @findings = findings
    end
  end
end
