# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Encryption at rest (F-02)", type: :model do
  let(:user) { create(:user) }
  let(:plaintext_marker) { "encryption-at-rest-#{SecureRandom.hex(8)}" }

  def raw_column_value(model_class, column, record_id)
    table = model_class.connection.quote_table_name(model_class.table_name)
    column_name = model_class.connection.quote_column_name(column.to_s)
    model_class.connection.select_value(
      "SELECT #{column_name} FROM #{table} WHERE id = #{record_id}"
    )
  end

  def expect_ciphertext_at_rest(model_class, column, record_id, plaintext)
    raw_value = raw_column_value(model_class, column, record_id)

    expect(raw_value).to be_present
    expect(raw_value).not_to include(plaintext)
    expect(model_class.find(record_id).public_send(column)).to eq(plaintext)
  end

  describe DebuggingCase do
    it "stores customer_reference as ciphertext in SQLite" do
      debugging_case = Intake::ProcessCaseSubmission.call(
        user: user,
        submission: Intake::CaseSubmission.new(
          title: "Encryption case",
          customer_reference: plaintext_marker,
          sources: [ { source_type: "rails_log", pasted_content: "ok" } ]
        )
      ).debugging_case

      expect_ciphertext_at_rest(
        DebuggingCase,
        :customer_reference,
        debugging_case.id,
        plaintext_marker
      )
    end
  end

  describe LogSource do
    it "stores sanitized_content as ciphertext in SQLite" do
      debugging_case = Intake::ProcessCaseSubmission.call(
        user: user,
        submission: Intake::CaseSubmission.new(
          title: "Encryption case",
          sources: [ { source_type: "rails_log", pasted_content: plaintext_marker } ]
        )
      ).debugging_case

      log_source = debugging_case.log_sources.first
      sanitized = log_source.sanitized_content

      expect_ciphertext_at_rest(
        LogSource,
        :sanitized_content,
        log_source.id,
        sanitized
      )
    end
  end

  describe CorrelationSignal do
    it "stores payload as ciphertext in SQLite" do
      debugging_case = Intake::ProcessCaseSubmission.call(
        user: user,
        submission: Intake::CaseSubmission.new(
          title: "Encryption case",
          sources: [ { source_type: "rails_log", pasted_content: "ok" } ]
        )
      ).debugging_case

      signal = debugging_case.correlation_signals.create!(payload: plaintext_marker)

      expect_ciphertext_at_rest(
        CorrelationSignal,
        :payload,
        signal.id,
        plaintext_marker
      )
    end
  end

  describe AiReport do
    it "stores structured_json and markdown_body as ciphertext in SQLite" do
      debugging_case = Intake::ProcessCaseSubmission.call(
        user: user,
        submission: Intake::CaseSubmission.new(
          title: "Encryption case",
          sources: [ { source_type: "rails_log", pasted_content: "ok" } ]
        )
      ).debugging_case

      report = debugging_case.ai_reports.create!(
        status: :generated,
        structured_json: plaintext_marker,
        markdown_body: "# #{plaintext_marker}"
      )

      expect_ciphertext_at_rest(
        AiReport,
        :structured_json,
        report.id,
        plaintext_marker
      )
      expect_ciphertext_at_rest(
        AiReport,
        :markdown_body,
        report.id,
        "# #{plaintext_marker}"
      )
    end
  end
end
