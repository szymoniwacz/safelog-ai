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
    expect(DebuggingCase.count).to eq(0)
  end
end
