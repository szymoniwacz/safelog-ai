# frozen_string_literal: true

require "rails_helper"

RSpec.describe DebuggingCasesHelper, type: :helper do
  def build_errors(attrs)
    submission = Intake::CaseSubmission.new(title: "Case", sources: [])
    submission.valid?
    attrs.each { |key, messages| Array(messages).each { |message| submission.errors.add(key, message) } }
    submission.errors
  end

  describe "#title_field_invalid?" do
    it "is true when title errors are present" do
      errors = build_errors(title: "can't be blank")

      expect(helper.title_field_invalid?(errors)).to be(true)
    end

    it "is false when title errors are absent" do
      errors = build_errors(sources: "must include at least one non-blank log source")

      expect(helper.title_field_invalid?(errors)).to be(false)
    end
  end

  describe "#missing_sources_error?" do
    it "detects the blank log source message" do
      errors = build_errors(sources: "must include at least one non-blank log source")

      expect(helper.missing_sources_error?(errors)).to be(true)
    end
  end

  describe "#invalid_source_slot_numbers" do
    it "parses slot numbers from invalid source type messages" do
      errors = build_errors(sources: "source 2 has an invalid source type")

      expect(helper.invalid_source_slot_numbers(errors)).to eq([ 2 ])
    end
  end

  describe "#form_field_css_class" do
    it "appends the invalid modifier when invalid" do
      expect(helper.form_field_css_class("form-field", invalid: true)).to eq("form-field form-field--invalid")
    end
  end

  describe "#log_source_type_options_for_select" do
    it "includes invalid submitted source types in the select options" do
      options = helper.log_source_type_options_for_select("invalid_type")

      expect(options).to include('value="invalid_type"')
      expect(options).to include("selected=\"selected\"")
    end
  end

  describe "#destroy_debugging_case_button" do
    let(:debugging_case) { instance_double(DebuggingCase, id: 42) }

    before do
      allow(helper).to receive(:debugging_case_path).with(debugging_case).and_return("/debugging_cases/42")
    end

    it "renders a delete button with an irreversible confirmation prompt" do
      html = helper.destroy_debugging_case_button(debugging_case)

      expect(html).to include('method="post"')
      expect(html).to include('value="delete"')
      expect(html).to include("onsubmit=")
      expect(html).to include(DebuggingCasesHelper::DESTROY_CASE_CONFIRMATION)
    end
  end
end
