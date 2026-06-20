# frozen_string_literal: true

module Analysis
  class AnalyzeCase
    FAILURE_MESSAGE = "Analysis could not be completed. Please try again later."

    Result = Data.define(:ai_report, :user_message) do
      def success?
        user_message.nil? && ai_report&.generated?
      end
    end

    def self.call(debugging_case:, client: Ai::ClientResolver.current)
      new(debugging_case: debugging_case, client: client).call
    end

    def initialize(debugging_case:, client:)
      @debugging_case = debugging_case
      @client = client
    end

    def call
      ai_report = @debugging_case.ai_reports.create!(status: :processing)
      correlation_payload = Correlation::ExtractSignals.call(debugging_case: @debugging_case)
      persist_correlation_signal!(correlation_payload)

      request = Analysis::PromptBuilder.call(
        debugging_case: @debugging_case,
        correlation_payload: correlation_payload
      )

      completion = complete_with_retry(request)

      ai_report.update!(
        status: :generated,
        structured_json: completion.structured.to_json,
        markdown_body: completion.markdown
      )

      success(ai_report)
    rescue Ai::InvalidResponseError, Faraday::Error
      ai_report&.update!(status: :failed, structured_json: nil, markdown_body: nil)
      failure(ai_report)
    end

    private

    def persist_correlation_signal!(correlation_payload)
      # Correlation::ExtractSignals is pure; this orchestrator owns persistence (S-03).
      @debugging_case.correlation_signals.create!(
        payload: JSON.generate(correlation_payload)
      )
    end

    def complete_with_retry(request)
      attempts = 0

      begin
        attempts += 1
        completion = @client.complete(request)
        Ai::ResponseValidator.call(completion.structured)
        completion
      rescue Ai::InvalidResponseError
        raise if attempts >= 2

        retry
      end
    end

    def success(ai_report)
      Result.new(ai_report: ai_report, user_message: nil)
    end

    def failure(ai_report)
      Result.new(ai_report: ai_report, user_message: FAILURE_MESSAGE)
    end
  end
end
