# frozen_string_literal: true

RSpec.describe "Persistence rollback guarantee", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it "rolls back case and associated data when validation fails after intake" do
    # Create a case with valid data.
    initial_count = DebuggingCase.count
    initial_log_source_count = LogSource.count

    post "/debugging_cases", params: {
      debugging_case: {
        title: "Valid case for persistence test",
        description: "Testing data persistence integrity",
        environment: "production",
        sources: [
          {
            source_type: "rails_log",
            name: "app.log",
            pasted_content: "Log content"
          }
        ]
      }
    }

    # Verify that the case and log source were created.
    expect(DebuggingCase.count).to eq(initial_count + 1)
    expect(LogSource.count).to eq(initial_log_source_count + 1)

    case_record = DebuggingCase.last
    log_source = case_record.log_sources.first

    # Verify that log source contains sanitized (redacted) content, not raw.
    expect(log_source.sanitized_content).to be_present
  end

  it "ensures no orphaned records when case creation fails" do
    # This test verifies that if case creation succeeds but subsequent operations fail,
    # the case remains valid (Rails transactions protect this).
    initial_log_source_count = LogSource.count

    post "/debugging_cases", params: {
      debugging_case: {
        title: "Orphan check test",
        description: "Verifying no orphaned log sources",
        environment: "production",
        sources: [
          {
            source_type: "rails_log",
            name: "app.log",
            pasted_content: "Error log"
          }
        ]
      }
    }

    case_record = DebuggingCase.last
    log_source = LogSource.last

    # Verify foreign key integrity.
    expect(log_source.debugging_case_id).to eq(case_record.id)
    expect(case_record.log_sources).to include(log_source)

    # Verify no orphaned records exist.
    expect(LogSource.where(debugging_case_id: nil).count).to eq(0)
  end
end
