# frozen_string_literal: true

# Canonical risk #1 oracle: raw intake substrings must not appear in persisted
# diagnostic columns after POST intake. Prefer this over show-response-only checks
# (anti-pattern: spec/requests/debugging_cases_spec.rb POST example).
module SecurityPersistenceHelpers
  TEST_LOG_PATH = Rails.root.join("log/test.log")

  # Bytes appended to log/test.log since +from_offset+ (test env request/SQL logging).
  # Proves filter_parameter_logging for intake params (:pasted_content, case metadata).
  # Not a dev/prod log audit; SQL bind logs are not scanned here.
  def appended_test_log_content(from_offset:)
    return "" unless TEST_LOG_PATH.exist?

    TEST_LOG_PATH.read.byteslice(from_offset..) || ""
  end

  def assert_no_raw_substring_in_appended_test_log(raw_substring, from_offset:)
    appended = appended_test_log_content(from_offset: from_offset)
    expect(appended).not_to include(raw_substring)
  end

  def assert_no_raw_substring_in_persisted_data(raw_substring, debugging_case: nil)
    cases =
      if debugging_case
        [ debugging_case.is_a?(DebuggingCase) ? debugging_case : DebuggingCase.find(debugging_case) ]
      else
        DebuggingCase.all
      end

    cases.each do |case_record|
      assert_case_tree_excludes_raw_substring(case_record, raw_substring)
    end
  end

  private

  def raw_column_value(model_class, column, record_id)
    table = model_class.connection.quote_table_name(model_class.table_name)
    column_name = model_class.connection.quote_column_name(column.to_s)
    model_class.connection.select_value(
      "SELECT #{column_name} FROM #{table} WHERE id = #{record_id.to_i}"
    )
  end

  def assert_case_tree_excludes_raw_substring(case_record, raw_substring)
    [
      case_record.title,
      case_record.description,
      case_record.environment,
      raw_column_value(DebuggingCase, :customer_reference, case_record.id)
    ].compact.each do |value|
      expect(value.to_s).not_to include(raw_substring)
    end

    case_record.log_sources.each do |log_source|
      [
        log_source.name,
        raw_column_value(LogSource, :sanitized_content, log_source.id)
      ].compact.each do |value|
        expect(value.to_s).not_to include(raw_substring)
      end

      log_source.redaction_findings.each do |finding|
        expect(finding.attributes.values.compact.join).not_to include(raw_substring)
      end
    end
  end
end
