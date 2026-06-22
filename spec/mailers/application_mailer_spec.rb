# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationMailer, type: :mailer do
  it "loads as an ActionMailer base class" do
    expect(described_class.superclass).to eq(ActionMailer::Base)
  end
end
