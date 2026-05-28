# frozen_string_literal: true

module Redaction
  class SummaryCounts
    def self.call(findings:)
      new(findings: findings).call
    end

    def initialize(findings:)
      @findings = findings
    end

    def call
      @findings.group_by { |finding| [ finding.finding_type, finding.risk_level ] }
               .transform_values(&:count)
               .sort_by { |(finding_type, risk_level), _count| [ finding_type, risk_level ] }
               .to_h
    end
  end
end
