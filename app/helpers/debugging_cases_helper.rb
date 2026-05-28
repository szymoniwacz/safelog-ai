# frozen_string_literal: true

module DebuggingCasesHelper
  SOURCE_SLOT_COUNT = 3

  def log_source_type_options
    LogSource.source_types.keys.map { |key| [ key.humanize, key ] }
  end

  def finding_type_label(finding_type)
    finding_type.to_s.humanize
  end
end
