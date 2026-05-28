# frozen_string_literal: true

module Correlation
  class ParsePayload
    def self.call(correlation_signal:)
      new(correlation_signal: correlation_signal).call
    end

    def initialize(correlation_signal:)
      @correlation_signal = correlation_signal
    end

    def call
      return [] if @correlation_signal&.payload.blank?

      JSON.parse(@correlation_signal.payload).fetch("signals", [])
    rescue JSON::ParserError
      []
    end
  end
end
