# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Debugging case user flow", type: :system do
  let(:email) { "flow-#{SecureRandom.hex(4)}@example.com" }
  let(:raw_email) { "customer-#{SecureRandom.hex(4)}@secret.example" }
  let(:raw_token) { "sk-flow-#{SecureRandom.hex(8)}" }
  let(:shared_request_id) { "req-flow-#{SecureRandom.hex(6)}" }

  before do
    sign_up_via_browser(email: email)
    expect(page).to have_text("Signed in as #{email}.")
  end

  it "creates a multi-source case, analyzes, exports, and archives from the browser" do
    click_link "New case"
    expect(page).to have_css("h1", text: "New debugging case")

    fill_in "Title", with: "E2E checkout failure"
    fill_in "Customer reference", with: "Contact #{raw_email}"

    fill_log_source_slot(
      1,
      source_type: "Rails log",
      name: "Rails",
      pasted_content: "User login failed for #{raw_email}\nAuthorization: Bearer #{raw_token}"
    )
    fill_log_source_slot(
      2,
      source_type: "Aws cloudwatch",
      pasted_content: "Timeout for request_id=#{shared_request_id}"
    )
    fill_log_source_slot(
      3,
      source_type: "Browser console",
      pasted_content: "Error for request_id=#{shared_request_id}"
    )

    click_button "Create debugging case"

    expect(page).to have_css("h1", text: "E2E checkout failure")
    expect(page).not_to have_text(raw_email)
    expect(page).not_to have_text(raw_token)
    expect(page).not_to have_text(shared_request_id)
    expect(page).to have_text("[EMAIL_1]")
    expect(page).to have_text("[AUTH_1]")
    expect(page).to have_css("h2", text: "Redaction summary")
    within(find("section.card", text: "Sanitized log sources")) do
      expect(page).to have_css("textarea", text: /\[EMAIL_1\]/)
      expect(page).to have_css("textarea", text: /\[AUTH_1\]/)
    end

    click_button "Analyze case"
    expect(page).to have_text("Analysis complete.")
    expect(page).to have_css("h2", text: "Hypothesis report")
    expect(page).to have_css("h2", text: "Correlation signals")
    expect(page).to have_text("[REQUEST_1]")
    expect(page).to have_link("download the report")
    within(find("section.card", text: "Hypothesis report")) do
      expect(page).to have_css("textarea[aria-label='Report Markdown']", text: /## Hypothesis report/)
    end

    debugging_case = DebuggingCase.last
    visit download_report_debugging_case_path(debugging_case)
    expect(page.body).to include("## Hypothesis report")
    expect(page.body).not_to include(raw_email)
    expect(page.body).not_to include(raw_token)

    visit debugging_case_path(debugging_case)
    click_button "Archive case"
    expect(page).to have_text("Case archived.")
    expect(page).to have_css("h1", text: "Debugging cases")

    click_link "Archived"
    expect(page).to have_link("E2E checkout failure")
    expect(page).not_to have_text("No archived debugging cases")

    click_link "Active"
    expect(page).to have_text("No active debugging cases yet")
  end
end
