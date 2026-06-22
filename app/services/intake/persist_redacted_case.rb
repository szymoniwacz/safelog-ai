# frozen_string_literal: true

module Intake
  class PersistRedactedCase
    SourcePayload = Data.define(:source_type, :name, :position, :sanitized_content, :findings)

    def self.call(user:, case_attributes:, sources:)
      new(user: user, case_attributes: case_attributes, sources: sources).call
    end

    def initialize(user:, case_attributes:, sources:)
      @user = user
      @case_attributes = case_attributes
      @sources = sources
    end

    def call
      debugging_case = nil

      DebuggingCase.transaction do
        debugging_case = @user.debugging_cases.create!(@case_attributes)

        @sources.each do |source_payload|
          log_source = debugging_case.log_sources.create!(
            source_type: source_payload.source_type,
            name: source_payload.name,
            position: source_payload.position,
            sanitized_content: source_payload.sanitized_content
          )

          source_payload.findings.each do |finding|
            log_source.redaction_findings.create!(
              RedactionFinding.build_from_engine_finding(finding)
            )
          end
        end
      end

      debugging_case
    end
  end
end
