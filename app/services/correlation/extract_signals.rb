# frozen_string_literal: true

require "set"

module Correlation
  class ExtractSignals
    PLACEHOLDER_PATTERN = /\[[A-Z]+_\d+\]/

    def self.call(debugging_case:)
      new(debugging_case: debugging_case).call
    end

    def initialize(debugging_case:)
      @debugging_case = debugging_case
    end

    def call
      sources = @debugging_case.log_sources.includes(:redaction_findings).order(:position)
      findings_by_placeholder = index_finding_types(sources)
      stats = tally_placeholders(sources)

      signals = stats.map do |placeholder, data|
        {
          placeholder: placeholder,
          finding_types: findings_by_placeholder[placeholder] || [],
          source_types: data[:source_types].to_a.sort,
          occurrence_count: data[:count]
        }
      end.sort_by { |signal| signal[:placeholder] }

      { signals: signals }
    end

    private

    def index_finding_types(sources)
      findings_by_placeholder = Hash.new { |placeholders, key| placeholders[key] = Set.new }

      sources.each do |source|
        source.redaction_findings.each do |finding|
          findings_by_placeholder[finding.placeholder] << finding.finding_type
        end
      end

      findings_by_placeholder.transform_values { |types| types.to_a.sort }
    end

    def tally_placeholders(sources)
      stats = Hash.new do |placeholders, key|
        placeholders[key] = { source_types: Set.new, count: 0 }
      end

      sources.each do |source|
        content = source.sanitized_content.to_s
        placeholders_in_source = Set.new

        content.scan(PLACEHOLDER_PATTERN) do |placeholder|
          stats[placeholder][:count] += 1
          placeholders_in_source << placeholder
        end

        placeholders_in_source.each do |placeholder|
          stats[placeholder][:source_types] << source.source_type
        end
      end

      stats
    end
  end
end
