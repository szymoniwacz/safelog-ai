# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Debugging case CRUD in the browser", type: :system do
  let(:email) { "crud-#{SecureRandom.hex(4)}@example.com" }

  before do
    sign_up_via_browser(email: email)
    expect(page).to have_text("Signed in as #{email}.")
  end

  it "edits metadata from the index and permanently deletes the case" do
    click_link "New case"
    fill_in "Title", with: "Browser CRUD case"
    fill_in "Description", with: "Initial notes"
    fill_log_source_slot(1, source_type: "Rails log", pasted_content: "request_id=req-crud-1")
    click_button "Create debugging case"

    expect(page).to have_css("h1", text: "Browser CRUD case")

    click_link "Cases"
    expect(page).to have_css("h1", text: "Debugging cases")
    expect(page).to have_link("Edit", href: edit_debugging_case_path(DebuggingCase.last))

    within(find("tr", text: "Browser CRUD case")) do
      click_link "Edit"
    end

    fill_in "Title", with: "Browser CRUD updated"
    fill_in "Description", with: "Updated notes"
    click_button "Save changes"

    expect(page).to have_text("Case updated.")
    expect(page).to have_css("h1", text: "Browser CRUD updated")
    expect(page).to have_text("Updated notes")

    click_link "Cases"
    within(find("tr", text: "Browser CRUD updated")) do
      click_button "Delete"
    end

    expect(page).to have_text("Case deleted.")
    expect(page).to have_css("h1", text: "Debugging cases")
    expect(page).not_to have_link("Browser CRUD updated")
    expect(DebuggingCase.find_by(title: "Browser CRUD updated")).to be_nil
  end
end
