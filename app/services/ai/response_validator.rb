# frozen_string_literal: true

module Ai
  class InvalidResponseError < StandardError; end

  class ResponseValidator
    ValidationResult = Data.define(:structured)

    def self.call(structured)
      new(structured).call
    end

    def initialize(structured)
      @structured = structured
    end

    def call
      raise InvalidResponseError, "structured response is required" if @structured.nil?

      data = symbolize_keys(@structured)
      validate!(data)
      ValidationResult.new(structured: data)
    end

    private

    def validate!(data)
      unless data.is_a?(Hash)
        raise InvalidResponseError, "structured response must be a hash"
      end

      ReportSchema::REQUIRED_KEYS.each do |key|
        unless data.key?(key)
          raise InvalidResponseError, "structured response is missing required key"
        end
      end

      validate_summary!(data[:summary])
      validate_hypotheses!(data[:hypotheses])
      validate_uncertainty_notes!(data[:uncertainty_notes])
      validate_correlation_highlights!(data[:correlation_highlights]) if data.key?(:correlation_highlights)
    end

    def validate_summary!(summary)
      unless summary.is_a?(String) && summary.strip.present?
        raise InvalidResponseError, "summary must be a non-empty string"
      end
    end

    def validate_hypotheses!(hypotheses)
      unless hypotheses.is_a?(Array) && hypotheses.any?
        raise InvalidResponseError, "hypotheses must be a non-empty array"
      end

      hypotheses.each do |hypothesis|
        unless hypothesis.is_a?(Hash)
          raise InvalidResponseError, "each hypothesis must be a hash"
        end

        hypothesis = symbolize_keys(hypothesis)
        ReportSchema::HYPOTHESIS_REQUIRED_KEYS.each do |key|
          unless hypothesis[key].is_a?(String) && hypothesis[key].strip.present?
            raise InvalidResponseError, "each hypothesis must include title and description"
          end
        end

        if hypothesis.key?(:confidence) && !hypothesis[:confidence].is_a?(String)
          raise InvalidResponseError, "hypothesis confidence must be a string when present"
        end
      end
    end

    def validate_uncertainty_notes!(notes)
      unless notes.is_a?(Array) && notes.any?
        raise InvalidResponseError, "uncertainty_notes must be a non-empty array"
      end

      notes.each do |note|
        unless note.is_a?(String) && note.strip.present?
          raise InvalidResponseError, "each uncertainty note must be a non-empty string"
        end
      end
    end

    def validate_correlation_highlights!(highlights)
      unless highlights.is_a?(Array)
        raise InvalidResponseError, "correlation_highlights must be an array when present"
      end

      highlights.each do |highlight|
        unless highlight.is_a?(String) && highlight.strip.present?
          raise InvalidResponseError, "each correlation highlight must be a non-empty string"
        end
      end
    end

    def symbolize_keys(value)
      case value
      when Hash
        value.to_h { |key, nested| [ key.to_sym, symbolize_keys(nested) ] }
      when Array
        value.map { |item| symbolize_keys(item) }
      else
        value
      end
    end
  end
end
