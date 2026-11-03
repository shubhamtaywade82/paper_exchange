require "rails_helper"

RSpec.describe "API Documentation", type: :request do
  describe "GET /api-docs" do
    it "renders the Swagger UI HTML interface unauthenticated" do
      get "/api-docs"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("SwaggerUIBundle")
      expect(response.body).to include("/api-docs/openapi.yaml")
    end
  end

  describe "GET /docs" do
    it "renders the Swagger UI interface" do
      get "/docs"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("SwaggerUIBundle")
    end
  end

  describe "GET /api-docs/openapi.yaml" do
    it "serves the OpenAPI 3.1 YAML specification" do
      get "/api-docs/openapi.yaml"
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("yaml")

      parsed = YAML.safe_load(response.body, permitted_classes: [ Date, Time ])
      expect(parsed["openapi"]).to eq("3.1.0")
      expect(parsed["paths"]).to include("/api/v1/orders", "/api/v1/account", "/api/v1/positions")
    end
  end

  describe "GET /api-docs/openapi.json" do
    it "serves the OpenAPI specification formatted as JSON" do
      get "/api-docs/openapi.json"
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/json")

      json = JSON.parse(response.body)
      expect(json["openapi"]).to eq("3.1.0")
      expect(json["info"]["title"]).to eq("PaperExchange API")
    end
  end
end
