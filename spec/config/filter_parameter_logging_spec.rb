# frozen_string_literal: true

require "rails_helper"

# Keep INTAKE_PARAM_KEYS in sync with spec/support/intake_param_filter_checklist.md
# and DebuggingCasesController#case_submission_params.
RSpec.describe "filter_parameter_logging intake params" do
  INTAKE_PARAM_KEYS = %i[
    pasted_content
    customer_reference
    title
    description
    environment
  ].freeze

  let(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }

  it "filters all documented intake param keys" do
    payload = INTAKE_PARAM_KEYS.index_with { |key| "secret-#{key}" }
    filtered = filter.filter(payload)

    INTAKE_PARAM_KEYS.each do |key|
      expect(filtered[key]).to eq("[FILTERED]"),
                               "expected #{key} to be filtered (add to config/initializers/filter_parameter_logging.rb)"
    end
  end

  it "filters nested pasted_content in sources params" do
    payload = {
      debugging_case: {
        title: "safe title",
        sources: [
          { source_type: "rails_log", pasted_content: "raw log line" }
        ]
      }
    }

    filtered = filter.filter(payload)
    source = filtered.dig(:debugging_case, :sources, 0)

    expect(source[:pasted_content]).to eq("[FILTERED]")
    expect(source[:source_type]).to eq("rails_log")
  end
end
