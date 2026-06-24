# frozen_string_literal: true

require "rails_helper"

RSpec.describe Demo::LoadCase do
  let(:user) { create(:user) }

  describe ".available?" do
    it "is true in the test environment" do
      expect(described_class.available?).to be(true)
    end

    it "is false in production when SAFELOG_ENABLE_DEMO_LOADER is unset" do
      allow(Rails.env).to receive(:development?).and_return(false)
      allow(Rails.env).to receive(:test?).and_return(false)
      allow(Rails.env).to receive(:production?).and_return(true)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("SAFELOG_ENABLE_DEMO_LOADER").and_return(nil)

      expect(described_class.available?).to be(false)
    end

    it "is true in production when SAFELOG_ENABLE_DEMO_LOADER is truthy" do
      allow(Rails.env).to receive(:development?).and_return(false)
      allow(Rails.env).to receive(:test?).and_return(false)
      allow(Rails.env).to receive(:production?).and_return(true)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("SAFELOG_ENABLE_DEMO_LOADER").and_return("true")

      expect(described_class.available?).to be(true)
    end

    it "is false when the environment is neither development, test, nor production" do
      allow(Rails.env).to receive(:development?).and_return(false)
      allow(Rails.env).to receive(:test?).and_return(false)
      allow(Rails.env).to receive(:production?).and_return(false)

      expect(described_class.available?).to be(false)
    end
  end

  describe ".call" do
    it "creates a demo case through the intake pipeline with sanitized sources" do
      result = described_class.call(user: user)

      expect(result).to be_success

      debugging_case = result.debugging_case
      expect(debugging_case.title).to include("Checkout payment timeout")
      expect(debugging_case.log_sources.count).to eq(3)

      sanitized_bodies = debugging_case.log_sources.order(:position).map(&:sanitized_content)
      expect(sanitized_bodies).to all(include("[REQUEST_1]"))
      expect(sanitized_bodies.join).to include("[EMAIL_1]")
      expect(sanitized_bodies.join).not_to include(Demo::CaseFixture::DEMO_EMAIL)
      expect(sanitized_bodies.join).not_to include(Demo::CaseFixture::DEMO_TOKEN)
      expect(sanitized_bodies.join).not_to include(Demo::CaseFixture::DEMO_REQUEST_ID)
    end

    it "raises when the demo loader is unavailable" do
      allow(described_class).to receive(:available?).and_return(false)

      expect { described_class.call(user: user) }.to raise_error(
        Demo::LoadCase::UnavailableError,
        /not available/
      )
    end
  end
end
