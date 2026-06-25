# frozen_string_literal: true

RSpec.describe "Redaction mapping non-persistence guarantee", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it "ensures raw→placeholder mappings are never persisted to database" do
    # Create a case with sensitive data that will trigger redaction.
    sensitive_content = "Email: secret@example.com\nPassword: SuperSecret123!"

    post "/debugging_cases", params: {
      debugging_case: {
        title: "Test mapping persistence",
        description: "Testing that mappings don't leak to DB",
        environment: "production",
        sources: [
          {
            source_type: "rails_log",
            name: "app.log",
            pasted_content: sensitive_content
          }
        ]
      }
    }

    expect(response).to have_http_status(:redirect)

    case_record = DebuggingCase.last
    expect(case_record).to be_present
    log_source = case_record.log_sources.first

    # Verify that:
    # 1. The log_source contains sanitized content (placeholders, not raw data).
    expect(log_source.sanitized_content).to include("[")
    expect(log_source.sanitized_content).to_not include("SuperSecret123!")
    expect(log_source.sanitized_content).to_not include("secret@example.com")

    # 2. No raw_ or original_ columns exist in the schema.
    schema_columns = case_record.class.columns.map(&:name)
    expect(schema_columns).to_not include("raw_content")
    expect(schema_columns).to_not include("original_content")
    expect(schema_columns).to_not include("encrypted_raw_content")

    # 3. Findings table stores only metadata (type, placeholder, line, risk).
    finding = case_record.log_sources.first.redaction_findings.first
    expect(finding).to have_attributes(
      placeholder: a_string_matching(/\[/),
      finding_type: an_instance_of(String),
      risk_level: an_instance_of(String),
      line_number: an_instance_of(Integer)
    )
    # Findings should NOT store the raw value or original text.
    expect(finding.attributes.values.map(&:to_s).join).to_not include("SuperSecret123!")
    expect(finding.attributes.values.map(&:to_s).join).to_not include("secret@example.com")
  end
end
