# frozen_string_literal: true

module SystemTestHelpers
  DEFAULT_PASSWORD = "password123"

  def sign_up_via_browser(email:, password: DEFAULT_PASSWORD)
    visit new_user_registration_path
    fill_in "Email", with: email
    fill_in "Password", with: password
    fill_in "Password confirmation", with: password
    click_button "Create account"
  end

  def sign_in_via_browser(email:, password: DEFAULT_PASSWORD)
    visit new_user_session_path
    fill_in "Email", with: email
    fill_in "Password", with: password
    click_button "Sign in"
  end

  def fill_log_source_slot(slot_number, source_type:, pasted_content:, name: nil)
    within(find("fieldset", text: "Log source #{slot_number}")) do
      select source_type, from: "Source type"
      fill_in "Name (optional)", with: name if name.present?
      fill_in "Pasted content", with: pasted_content
    end
  end
end
