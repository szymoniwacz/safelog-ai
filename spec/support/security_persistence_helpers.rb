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

  def assert_no_raw_substring_in_persisted_data(raw_substring)
    DebuggingCase.find_each do |debugging_case|
      [
        debugging_case.title,
        debugging_case.description,
        debugging_case.environment,
        debugging_case.customer_reference
      ].compact.each do |value|
        expect(value.to_s).not_to include(raw_substring)
      end
    end

    LogSource.find_each do |log_source|
      expect(log_source.name.to_s).not_to include(raw_substring)
      expect(log_source.sanitized_content.to_s).not_to include(raw_substring)
    end

    RedactionFinding.find_each do |finding|
      expect(finding.attributes.values.compact.join).not_to include(raw_substring)
    end
  end
end
