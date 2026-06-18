# frozen_string_literal: true

module DebuggingCasesHelper
  SOURCE_SLOT_COUNT = 3

  def log_source_type_options
    LogSource.source_types.keys.map { |key| [ key.humanize, key ] }
  end

  def finding_type_label(finding_type)
    finding_type.to_s.humanize
  end

  def log_source_count_label(debugging_case)
    count = debugging_case.log_sources.size
    "#{count} #{'source'.pluralize(count)}"
  end

  def analysis_status_label(debugging_case)
    {
      not_analyzed: "Not analyzed",
      analyzed: "Analyzed",
      failed: "Analysis failed",
      in_progress: "In progress"
    }.fetch(debugging_case.analysis_status)
  end

  def analysis_status_badge_class(debugging_case)
    {
      not_analyzed: "status-badge status-badge--muted",
      analyzed: "status-badge status-badge--success",
      failed: "status-badge status-badge--danger",
      in_progress: "status-badge status-badge--warning"
    }.fetch(debugging_case.analysis_status)
  end
end
