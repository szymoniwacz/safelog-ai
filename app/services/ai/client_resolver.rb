# frozen_string_literal: true

module Ai
  class ClientResolver
    def self.current
      return FakeClient.new if Rails.env.test?
      return OpenAiClient.new if ENV["OPENAI_API_KEY"].present?

      FakeClient.new
    end
  end
end
