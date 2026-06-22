# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::Client do
  it "raises NotImplementedError when #complete is not overridden" do
    client = Class.new { include Ai::Client }.new

    expect { client.complete(nil) }.to raise_error(
      NotImplementedError,
      "#{client.class} must implement #complete"
    )
  end
end
