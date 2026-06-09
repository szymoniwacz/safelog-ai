# frozen_string_literal: true

require "capybara/rspec"

# Rack-test driver: same-thread requests, works with transactional fixtures,
# stable for server-rendered forms (no JS-only flows in MVP).
Capybara.default_driver = :rack_test
Capybara.default_max_wait_time = 5

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  # Public 404/422 pages instead of debug traces (test env defaults to local).
  config.around(:each, type: :system) do |example|
    prior = Rails.application.config.consider_all_requests_local
    Rails.application.config.consider_all_requests_local = false
    example.run
  ensure
    Rails.application.config.consider_all_requests_local = prior
  end
end
