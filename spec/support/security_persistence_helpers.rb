# frozen_string_literal: true

# Canonical risk #1 oracle: raw intake substrings must not appear in persisted
# diagnostic columns after POST intake. Prefer this over show-response-only checks
# (anti-pattern: spec/requests/debugging_cases_spec.rb POST example).
module SecurityPersistenceHelpers
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
      expect(log_source.sanitized_content.to_s).not_to include(raw_substring)
    end

    RedactionFinding.find_each do |finding|
      expect(finding.attributes.values.compact.join).not_to include(raw_substring)
    end
  end
end
