# frozen_string_literal: true

module Demo
  class LoadCase
    UnavailableError = Class.new(StandardError)

    def self.available?
      Rails.env.development? || Rails.env.test?
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
