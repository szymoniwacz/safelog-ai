# frozen_string_literal: true

module Intake
  class CaseSubmission
    include ActiveModel::Model
    include ActiveModel::Validations

    Source = Data.define(:source_type, :name, :pasted_content)

    MAX_PASTED_CONTENT_LENGTH = 256_000

    attr_accessor :title, :description, :customer_reference, :environment, :sources

    validates :title, presence: true
    validate :at_least_one_source_with_content
    validate :source_types_are_valid
    validate :pasted_content_within_limit

    def initialize(attributes = {})
      super
      self.sources = normalize_sources(sources)
    end

    def sources_with_content
      sources.select { |source| source.pasted_content.present? }
    end

    private

    def normalize_sources(raw_sources)
      Array(raw_sources).map do |source|
        Source.new(
          source_type: source[:source_type] || source["source_type"],
          name: (source[:name] || source["name"]).to_s.strip.presence,
          pasted_content: (source[:pasted_content] || source["pasted_content"]).to_s.strip
        )
      end
    end

    def at_least_one_source_with_content
      return if sources_with_content.any?

      errors.add(:sources, "must include at least one non-blank log source")
    end

    def source_types_are_valid
      sources.each_with_index do |source, index|
        next if source.pasted_content.blank?
        next if LogSource.source_types.key?(source.source_type.to_s)

        errors.add(:sources, "source #{index + 1} has an invalid source type")
      end
    end

    def pasted_content_within_limit
      sources.each_with_index do |source, index|
        next if source.pasted_content.blank?
        next if source.pasted_content.length <= MAX_PASTED_CONTENT_LENGTH

        errors.add(
          :sources,
          "source #{index + 1} pasted content exceeds the 256KB limit"
        )
      end
    end
  end
end
