# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Debugging case validation", type: :system do
  before do
    user = create(:user, email: "validation-#{SecureRandom.hex(4)}@example.com")
    sign_in_via_browser(email: user.email)
  end

  it "re-renders the new case form with validation errors when no log sources are provided" do
    visit new_debugging_case_path

    fill_in "Title", with: "Missing sources case"
    click_button "Create debugging case"

    expect(page).to have_current_path(debugging_cases_path)
    expect(page).to have_css("h1", text: "New debugging case")
    expect(page).to have_text("prohibited this case from being saved")
    expect(page).to have_text("must include at least one non-blank log source")
    expect(page).to have_field("Title", with: "Missing sources case")
    expect(page).to have_css(".form-field--invalid")
  end

  it "preserves metadata fields when validation fails" do
    visit new_debugging_case_path

    fill_in "Title", with: "Metadata preserve case"
    fill_in "Description", with: "Reporter notes"
    fill_in "Customer reference", with: "Ticket #999"
    fill_in "Environment", with: "staging"
    click_button "Create debugging case"

    expect(page).to have_css("h1", text: "New debugging case")
    expect(page).to have_field("Title", with: "Metadata preserve case")
    expect(page).to have_field("Description", with: "Reporter notes")
    expect(page).to have_field("Customer reference", with: "Ticket #999")
    expect(page).to have_field("Environment", with: "staging")
  end

  it "preserves source metadata and highlights invalid slots without re-rendering paste" do
    visit new_debugging_case_path

    fill_in "Title", with: "Invalid source type case"
    within(find("fieldset", text: "Log source 1")) do
      fill_in "Name (optional)", with: "Rails"
      fill_in "Pasted content", with: "secret-token-#{SecureRandom.hex(4)}"
    end
    click_button "Create debugging case"

    expect(page).to have_css("h1", text: "New debugging case")
    expect(page).to have_css("fieldset.fieldset--invalid", text: "Log source 1")
    expect(page).to have_field("Name (optional)", with: "Rails")
    expect(page).to have_field("Pasted content", with: "")
    expect(page).to have_text("Pasted log content was cleared for security")
  end
end
