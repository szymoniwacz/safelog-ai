# frozen_string_literal: true

module Analysis
  class ReportFilename
    def self.call(debugging_case:)
      new(debugging_case: debugging_case).call
    end

    def initialize(debugging_case:)
      @debugging_case = debugging_case
    end

    def call
      base = @debugging_case.title.to_s.parameterize.presence || "debugging-case-#{@debugging_case.id}"
      "#{base}-report.md"
    end
  end
end
