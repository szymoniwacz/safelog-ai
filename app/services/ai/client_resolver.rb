# frozen_string_literal: true

module Ai
  class ClientResolver
    def self.current
      if Rails.env.test?
        return InvalidClient.new if Ai::E2eContext.client_mode == "invalid"
        return FakeClient.new
      end
      return OpenAiClient.new if ENV["OPENAI_API_KEY"].present?

      FakeClient.new
    end

    def self.fake_client_active?
      !Rails.env.test? && ENV["OPENAI_API_KEY"].blank?
    end
  end
end
