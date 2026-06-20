class RedactionFinding < ApplicationRecord
  belongs_to :log_source

  validates :finding_type, :line_number, :placeholder, :risk_level, presence: true

  PERSISTED_ATTRIBUTES = %i[finding_type line_number placeholder risk_level].freeze

  def self.build_from_engine_finding(finding)
    unless finding.is_a?(Redaction::Finding)
      raise ArgumentError, "expected Redaction::Finding, got #{finding.class}"
    end

    {
      finding_type: finding.finding_type,
      line_number: finding.line_number,
      placeholder: finding.placeholder,
      risk_level: finding.risk_level
    }
  end
end
