# frozen_string_literal: true

require "rails_helper"

RSpec.describe "User isolation", type: :system do
  let(:owner) { create(:user, email: "owner-#{SecureRandom.hex(4)}@example.com") }
  let(:other_user) { create(:user, email: "other-#{SecureRandom.hex(4)}@example.com") }

  let!(:debugging_case) do
    Intake::ProcessCaseSubmission.call(
      user: owner,
      submission: Intake::CaseSubmission.new(
        title: "Owner-only browser case",
        sources: [
          { source_type: "rails_log", pasted_content: "request_id=req-browser-isolation-1" }
        ]
      )
    ).debugging_case
  end

  it "does not show another user's case content in the browser" do
    sign_in_via_browser(email: other_user.email)

    visit debugging_case_path(debugging_case)

    expect(page).to have_http_status(:not_found)
    expect(page).to have_text("The page you were looking for doesn't exist")
    expect(page).not_to have_css("h1", text: "Owner-only browser case")
    expect(page).not_to have_css("h2", text: "Sanitized log sources")
    expect(page).not_to have_text("[REQUEST_1]")
  end
end
