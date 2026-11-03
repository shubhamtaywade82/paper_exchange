# Serves OpenAPI specification and Swagger UI without requiring ActionView
# or asset pipelines in this API-only application.
class ApiDocsController < ApplicationController
  def index
    render html: swagger_ui_html.html_safe, layout: false
  end

  def openapi_yaml
    send_file Rails.root.join("public/api-docs/openapi.yaml"),
              type: "text/yaml",
              disposition: "inline"
  end

  def openapi_json
    spec = YAML.safe_load_file(
      Rails.root.join("public/api-docs/openapi.yaml"),
      permitted_classes: [ Date, Time ]
    )
    render json: spec
  end

  private

  def swagger_ui_html
    File.read(Rails.root.join("public/api-docs/index.html"))
  end
end
