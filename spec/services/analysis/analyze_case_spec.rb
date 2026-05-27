# frozen_string_literal: true

require "rails_helper"

RSpec.describe Analysis::AnalyzeCase do
  let(:user) { create(:user) }

  def create_case_from_submission(submission_attrs)
    submission = Intake::CaseSubmission.new(submission_attrs)
    Intake::ProcessCaseSubmission.call(user: user, submission: submission).debugging_case
  end

  describe ".call" do
    it "persists correlation signals and a generated AI report" do
      debugging_case = create_case_from_submission(
        title: "Analyze me",
        sources: [
          {
            source_type: "rails_log",
            pasted_content: "request_id=req-analyze-123"
          },
          {
            source_type: "aws_cloudwatch",
            pasted_content: "Timeout for request_id=req-analyze-123"
          }
        ]
      )
      client = Ai::FakeClient.new

      result = described_class.call(debugging_case: debugging_case, client: client)

      expect(result).to be_success
      expect(result.user_message).to be_nil

      ai_report = result.ai_report
      expect(ai_report).to be_generated
      expect(ai_report.structured_json).to be_present
      expect(ai_report.markdown_body).to be_present

      expect(debugging_case.correlation_signals.count).to eq(1)
      payload = JSON.parse(debugging_case.correlation_signals.last.payload)
      expect(payload["signals"].first["placeholder"]).to eq("[REQUEST_1]")
    end

    it "does not send raw intake secrets to the AI client" do
      secret_email = "analyze-#{SecureRandom.hex(4)}@secret.example"
      debugging_case = create_case_from_submission(
        title: "Secret guard",
        sources: [
          { source_type: "rails_log", pasted_content: "Failed for #{secret_email}" }
        ]
      )
      client = Ai::FakeClient.new

      described_class.call(debugging_case: debugging_case, client: client)

      prompt = client.last_request.messages.map { |message| message[:content] }.join("\n")
      expect(prompt).to include("[EMAIL_1]")
      expect(prompt).not_to include(secret_email)
    end

    it "retries once on invalid AI output and succeeds on the second attempt" do
      debugging_case = create_case_from_submission(
        title: "Retry success",
        sources: [
          { source_type: "rails_log", pasted_content: "request_id=req-retry-ok-1" }
        ]
      )
      client = InvalidOnceClient.new

      result = described_class.call(debugging_case: debugging_case, client: client)

      expect(result).to be_success
      expect(client.complete_calls).to eq(2)
    end

    it "marks the report failed after two invalid AI responses" do
      debugging_case = create_case_from_submission(
        title: "Retry failure",
        sources: [
          { source_type: "rails_log", pasted_content: "request_id=req-retry-fail-1" }
        ]
      )
      client = InvalidClient.new

      result = described_class.call(debugging_case: debugging_case, client: client)

      expect(result).not_to be_success
      expect(result.user_message).to eq(Analysis::AnalyzeCase::FAILURE_MESSAGE)
      expect(result.ai_report).to be_failed
      expect(result.ai_report.structured_json).to be_nil
      expect(result.ai_report.markdown_body).to be_nil
      expect(client.complete_calls).to eq(2)
    end
  end

  class InvalidOnceClient
    include Ai::Client

    attr_reader :complete_calls, :last_request

    def initialize
      @complete_calls = 0
      @fallback = Ai::FakeClient.new
    end

    def complete(request)
      @complete_calls += 1
      @last_request = request

      if @complete_calls == 1
        Ai::CompletionResult.new(structured: { summary: "" }, markdown: "")
      else
        @fallback.complete(request)
      end
    end
  end

  class InvalidClient
    include Ai::Client

    attr_reader :complete_calls, :last_request

    def initialize
      @complete_calls = 0
    end

    def complete(request)
      @complete_calls += 1
      @last_request = request

      Ai::CompletionResult.new(structured: { summary: "" }, markdown: "")
    end
  end
end
