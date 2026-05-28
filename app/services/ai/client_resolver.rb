# frozen_string_literal: true

module Ai
  class ClientResolver
    def self.current
      return FakeClient.new if Rails.env.test?
      return OpenAiClient.new if ENV["OPENAI_API_KEY"].present?

      FakeClient.new
    end

    def self.fake_client_active?
      !Rails.env.test? && ENV["OPENAI_API_KEY"].blank?
    end
  end
end
