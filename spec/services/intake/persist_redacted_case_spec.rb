# frozen_string_literal: true

require "rails_helper"

RSpec.describe Intake::PersistRedactedCase do
  let(:user) { create(:user) }

  def build_case_attributes(overrides = {})
    {
      title: "Checkout timeout",
      description: "Customer cannot complete payment",
      customer_reference: "[REQUEST_1]",
      environment: "production"
    }.merge(overrides)
  end

  def build_source_payload(overrides = {})
    defaults = {
      source_type: "rails_log",
      name: "Rails",
      position: 0,
      sanitized_content: "Started GET /checkout [REQUEST_1]",
      findings: [
        Redaction::Finding.new(
          finding_type: "request_id",
          line_number: 1,
          placeholder: "[REQUEST_1]",
          risk_level: "medium"
        )
      ]
    }

    described_class::SourcePayload.new(**defaults.merge(overrides))
  end

  describe ".call" do
    it "persists a case with log sources and findings" do
      debugging_case = described_class.call(
        user: user,
        case_attributes: build_case_attributes(title: "Incident for [EMAIL_1]"),
        sources: [
          build_source_payload(
            sanitized_content: "User login failed for [EMAIL_1]",
            findings: [
              Redaction::Finding.new(
                finding_type: "email",
                line_number: 1,
                placeholder: "[EMAIL_1]",
                risk_level: "high"
              )
            ]
          ),
          build_source_payload(
            source_type: "browser_console",
            name: "Browser",
            position: 1,
            sanitized_content: "[REQUEST_1]",
            findings: [
              Redaction::Finding.new(
                finding_type: "request_id",
                line_number: 1,
                placeholder: "[REQUEST_1]",
                risk_level: "medium"
              )
            ]
          )
        ]
      )

      expect(debugging_case).to be_persisted
      expect(debugging_case.log_sources.count).to eq(2)
      expect(debugging_case.log_sources.flat_map(&:redaction_findings).count).to eq(2)
      expect(debugging_case.log_sources.first.sanitized_content).to include("[EMAIL_1]")
    end

    it "rolls back the entire transaction when log_sources.create! fails (G-01)" do
      invalid_record = LogSource.new
      invalid_record.errors.add(:sanitized_content, "forced log source failure")

      allow_any_instance_of(DebuggingCase).to receive(:log_sources).and_wrap_original do |method, *args|
        association = method.call(*args)
        allow(association).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(invalid_record))
        association
      end

      expect do
        expect do
          described_class.call(
            user: user,
            case_attributes: build_case_attributes,
            sources: [ build_source_payload ]
          )
        end.to raise_error(ActiveRecord::RecordInvalid) do |error|
          expect(error.record.errors[:sanitized_content]).to include("forced log source failure")
        end
      end.not_to change(DebuggingCase, :count)
    end

    it "rolls back the entire transaction when redaction_findings.create! fails (G-02)" do
      invalid_record = RedactionFinding.new
      invalid_record.errors.add(:placeholder, "forced finding failure")

      allow_any_instance_of(LogSource).to receive(:redaction_findings).and_wrap_original do |method, *args|
        association = method.call(*args)
        allow(association).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(invalid_record))
        association
      end

      expect do
        expect do
          described_class.call(
            user: user,
            case_attributes: build_case_attributes,
            sources: [
              build_source_payload(
                findings: [
                  Redaction::Finding.new(
                    finding_type: "email",
                    line_number: 1,
                    placeholder: "[EMAIL_1]",
                    risk_level: "high"
                  )
                ]
              )
            ]
          )
        end.to raise_error(ActiveRecord::RecordInvalid) do |error|
          expect(error.record.errors[:placeholder]).to include("forced finding failure")
        end
      end.not_to change(DebuggingCase, :count)
    end
  end
end
