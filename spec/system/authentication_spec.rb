# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Authentication", type: :system do
  let(:password) { SystemTestHelpers::DEFAULT_PASSWORD }

  describe "guest access" do
    it "redirects unauthenticated visitors to sign in from the dashboard and cases index" do
      visit root_path
      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_css("h1", text: "Sign in to SafeLog AI")

      visit debugging_cases_path
      expect(page).to have_current_path(new_user_session_path)
    end
  end

  describe "sign up" do
    it "registers a new user and lands on the dashboard" do
      email = "signup-#{SecureRandom.hex(4)}@example.com"

      sign_up_via_browser(email: email, password: password)

      expect(page).to have_current_path(root_path)
      expect(page).to have_text("Signed in as #{email}.")
      expect(page).to have_link("Cases", href: debugging_cases_path)
      expect(page).to have_link("New case", href: new_debugging_case_path)
    end
  end

  describe "sign in and sign out" do
    let(:user) { create(:user, email: "signin-#{SecureRandom.hex(4)}@example.com", password: password) }

    it "signs in an existing user and signs out from the header" do
      sign_in_via_browser(email: user.email, password: password)

      expect(page).to have_current_path(root_path)
      expect(page).to have_text("Signed in as #{user.email}.")

      click_button "Sign out"

      visit root_path
      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_css("h1", text: "Sign in to SafeLog AI")
    end
  end
end
