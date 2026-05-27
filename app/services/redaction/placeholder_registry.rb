# frozen_string_literal: true

module Redaction
  # In-memory only — never persist, log, or serialize raw-to-placeholder mappings.
  class PlaceholderRegistry
    def initialize
      @placeholders = {}
      @counters = Hash.new(0)
    end

    def placeholder_for(type:, value:)
      normalized = normalize(value)
      key = [ type.to_s, normalized ]

      return @placeholders[key] if @placeholders.key?(key)

      @counters[type] += 1
      placeholder = "[#{type}_#{@counters[type]}]"
      @placeholders[key] = placeholder
      placeholder
    end

    private

    def normalize(value)
      value.to_s.strip
    end
  end
end
