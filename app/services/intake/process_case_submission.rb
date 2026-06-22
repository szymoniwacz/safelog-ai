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

      case_attributes = {
        title: RedactMetadata.call(@submission.title, registry: registry),
        description: RedactMetadata.call(@submission.description, registry: registry),
        environment: RedactMetadata.call(@submission.environment, registry: registry),
        customer_reference: RedactMetadata.call(@submission.customer_reference, registry: registry)
      }

      sources = @submission.sources_with_content.each_with_index.map do |source, index|
        result = Redaction::Engine.redact(source.pasted_content, registry: registry)

        PersistRedactedCase::SourcePayload.new(
          source_type: source.source_type,
          name: RedactMetadata.call(source.name, registry: registry),
          position: index,
          sanitized_content: result.sanitized_text,
          findings: result.findings
        )
      end

      debugging_case = PersistRedactedCase.call(
        user: @user,
        case_attributes: case_attributes,
        sources: sources
      )

      success(debugging_case)
    rescue ActiveRecord::RecordInvalid => error
      failure(error.record.errors)
    end

    private

    def success(debugging_case)
      Result.new(debugging_case: debugging_case, errors: nil)
    end

    def failure(errors)
      Result.new(debugging_case: nil, errors: errors)
    end
  end
end
