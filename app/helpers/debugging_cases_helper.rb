# frozen_string_literal: true

module DebuggingCasesHelper
  SOURCE_SLOT_COUNT = 3
  MISSING_SOURCES_MESSAGE = "must include at least one non-blank log source"

  def log_source_type_options
    LogSource.source_types.keys.map { |key| [ key.humanize, key ] }
  end

  def log_source_type_options_for_select(selected)
    options = log_source_type_options
    selected = selected.to_s.presence
    if selected && options.none? { |(_, value)| value == selected }
      options = options + [ [ selected.humanize, selected ] ]
    end

    options_for_select(options, selected)
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

  def title_field_invalid?(errors)
    errors.present? && errors[:title].any?
  end

  def sources_error_messages(errors)
    return [] if errors.blank?

    errors[:sources]
  end

  def missing_sources_error?(errors)
    sources_error_messages(errors).any? { |message| message.include?(MISSING_SOURCES_MESSAGE) }
  end

  def invalid_source_slot_numbers(errors)
    sources_error_messages(errors).filter_map do |message|
      message[/\Asource (\d+) has an invalid source type\z/, 1]&.to_i
    end
  end

  def source_slot_invalid?(errors, slot_number)
    missing_sources_error?(errors) || invalid_source_slot_numbers(errors).include?(slot_number)
  end

  def form_field_css_class(base, invalid: false)
    invalid ? "#{base} #{base}--invalid" : base
  end

  def field_error_id(field_key)
    "error_#{field_key}"
  end
end
