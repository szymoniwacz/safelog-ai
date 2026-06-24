# frozen_string_literal: true

module Demo
  class LoadCase
    UnavailableError = Class.new(StandardError)

    def self.available?
      return true if Rails.env.development? || Rails.env.test?
      return demo_loader_enabled? if Rails.env.production?

      false
    end

    def self.demo_loader_enabled?
      %w[1 true yes].include?(ENV["SAFELOG_ENABLE_DEMO_LOADER"]&.downcase)
    end

    def self.call(user:)
      new(user: user).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      raise UnavailableError, "demo loader is not available in this environment" unless self.class.available?

      submission = Intake::CaseSubmission.new(Demo::CaseFixture.submission_attributes)
      Intake::ProcessCaseSubmission.call(user: @user, submission: submission)
    end
  end
end
