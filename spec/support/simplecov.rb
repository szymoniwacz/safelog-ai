# frozen_string_literal: true

require "simplecov"

SimpleCov.start do
  enable_coverage :branch

  add_filter "/spec/"
  add_filter "/vendor/"
  add_filter "/config/"
  add_filter "/lib/"

  track_files "app/**/*.rb"

  minimum_coverage line: 100, branch: 100
end
