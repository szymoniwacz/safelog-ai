# frozen_string_literal: true

RSpec.describe HealthController, type: :request do
  describe "GET /healthz" do
    it "returns 200 with healthy status" do
      get "/healthz"

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/json")

      body = JSON.parse(response.body)
      expect(body["status"]).to eq("healthy")
      expect(body["timestamp"]).to be_present
    end
  end

  describe "GET /health" do
    it "returns 200 with healthy status" do
      get "/health"

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/json")

      body = JSON.parse(response.body)
      expect(body["status"]).to eq("healthy")
    end
  end

  describe "GET /up" do
    it "returns 200 for Rails health check" do
      get "/up"
      expect(response).to have_http_status(:ok)
    end
  end
end
