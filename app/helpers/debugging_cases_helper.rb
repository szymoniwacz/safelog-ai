# frozen_string_literal: true

module DebuggingCasesHelper
  SOURCE_SLOT_COUNT = 3

  def log_source_type_options
    LogSource.source_types.keys.map { |key| [ key.humanize, key ] }
  end

  def finding_type_label(finding_type)
    finding_type.to_s.humanize
  end

  def redaction_summary_counts(findings)
    findings.group_by { |finding| [ finding.finding_type, finding.risk_level ] }
            .transform_values(&:count)
            .sort_by { |(finding_type, risk_level), _count| [ finding_type, risk_level ] }
  end

  def parse_correlation_signals(correlation_signal)
    return [] if correlation_signal&.payload.blank?

    JSON.parse(correlation_signal.payload).fetch("signals", [])
  rescue JSON::ParserError
    []
  end

  def parse_ai_report_structured(ai_report)
    return nil if ai_report&.structured_json.blank?

    JSON.parse(ai_report.structured_json)
  rescue JSON::ParserError
    nil
  end
end
