# frozen_string_literal: true

module Intake
  class ProcessCaseSubmission
    Result = Data.define(:debugging_case, :errors) do
      def success?
        errors.blank?
      end
    end

    def self.call(user:, submission:)
      new(user: user, submission: submission).call
    end

    def initialize(user:, submission:)
      @user = user
      @submission = submission
    end

    def call
      return failure(@submission.errors) unless @submission.valid?

      registry = Redaction::PlaceholderRegistry.new

      debugging_case = nil

      DebuggingCase.transaction do
        debugging_case = @user.debugging_cases.create!(
          title: @submission.title,
          description: @submission.description,
          environment: @submission.environment,
          customer_reference: redact_metadata(@submission.customer_reference, registry)
        )

        @submission.sources_with_content.each_with_index do |source, index|
          result = Redaction::Engine.redact(source.pasted_content, registry: registry)

          log_source = debugging_case.log_sources.create!(
            source_type: source.source_type,
            name: source.name,
            position: index,
            sanitized_content: result.sanitized_text
          )

          result.findings.each do |finding|
            log_source.redaction_findings.create!(finding)
          end
        end
      end

      success(debugging_case)
    rescue ActiveRecord::RecordInvalid => error
      failure(error.record.errors)
    end

    private

    def redact_metadata(text, registry)
      return if text.blank?

      Redaction::Engine.redact(text, registry: registry).sanitized_text
    end

    def success(debugging_case)
      Result.new(debugging_case: debugging_case, errors: nil)
    end

    def failure(errors)
      Result.new(debugging_case: nil, errors: errors)
    end
  end
end
