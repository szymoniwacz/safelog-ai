# frozen_string_literal: true

require "simplecov"

enforce_coverage_threshold =
  ENV["CI"] ||
  begin
    spec_targets = ARGV.reject { |arg| arg.start_with?("-") }
    spec_targets.empty? || spec_targets == %w[spec] || spec_targets == %w[spec/]
  end

SimpleCov.start do
  enable_coverage :branch

  add_filter "/spec/"
  add_filter "/vendor/"
  add_filter "/config/"
  add_filter "/lib/"

  track_files "app/**/*.rb"

  minimum_coverage line: 100, branch: 100 if enforce_coverage_threshold
end
