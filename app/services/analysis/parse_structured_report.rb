# frozen_string_literal: true

module Analysis
  class ParseStructuredReport
    def self.call(ai_report:)
      new(ai_report: ai_report).call
    end

    def initialize(ai_report:)
      @ai_report = ai_report
    end

    def call
      return nil if @ai_report&.structured_json.blank?

      JSON.parse(@ai_report.structured_json)
    rescue JSON::ParserError
      nil
    end
  end
end
