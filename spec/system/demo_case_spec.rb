# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Demo case loader", type: :system do
  before do
    user = create(:user, email: "demo-#{SecureRandom.hex(4)}@example.com")
    sign_in_via_browser(email: user.email)
  end

  it "loads the demo case from the dashboard with sanitized evidence visible" do
    visit root_path

    expect(page).to have_button("Load demo case")
    click_button "Load demo case"

    expect(page).to have_text("Demo case loaded.")
    expect(page).to have_css("h1", text: /Checkout payment timeout/)
    expect(page).to have_text("[REQUEST_1]")
    expect(page).not_to have_text(Demo::CaseFixture::DEMO_EMAIL)
    expect(page).not_to have_text(Demo::CaseFixture::DEMO_TOKEN)
    expect(page).to have_css("h2", text: "Sanitized log sources")
  end
end
