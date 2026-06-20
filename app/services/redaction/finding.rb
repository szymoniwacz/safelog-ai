# frozen_string_literal: true

module Redaction
  Finding = Data.define(:finding_type, :line_number, :placeholder, :risk_level) do
    def initialize(finding_type:, line_number:, placeholder:, risk_level:)
      validate_presence!(:finding_type, finding_type)
      validate_presence!(:line_number, line_number)
      validate_presence!(:placeholder, placeholder)
      validate_presence!(:risk_level, risk_level)

      super(
        finding_type: finding_type.to_s,
        line_number: line_number,
        placeholder: placeholder.to_s,
        risk_level: risk_level.to_s
      )
    end

    private

    def validate_presence!(name, value)
      return if value.present?

      raise ArgumentError, "#{name} must be present"
    end
  end
end
