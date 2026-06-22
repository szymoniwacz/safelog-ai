# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::CompletionResult do
  describe "#initialize" do
    it "requires structured to be a hash" do
      expect do
        described_class.new(structured: "not-a-hash", markdown: "ok")
      end.to raise_error(ArgumentError, "structured must be a hash")
    end

    it "requires markdown to be a string" do
      expect do
        described_class.new(structured: { summary: "ok" }, markdown: 123)
      end.to raise_error(ArgumentError, "markdown must be a string")
    end
  end
end
