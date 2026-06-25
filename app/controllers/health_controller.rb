# frozen_string_literal: true

class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token

  def check
    render json: { status: "healthy", timestamp: Time.current.iso8601 }, status: :ok
  end
end
