module Api
  class BaseController < ApplicationController
    before_action :set_account

    private

    def set_account
      @account_id = (request.headers["X-Account-Id"].presence ||
                     request.headers["X-API-Key"].presence ||
                     params[:account_id].presence ||
                     "default").to_s
      # Test scaffolding only — never active in production. Without this gate,
      # anyone hitting the public API with X-API-Key: test-api-key-123 was
      # silently mapped to the test-account-1 wallet (B4).
      if Rails.env.test? && @account_id == "test-api-key-123" && !Account.exists?(account_id: @account_id)
        @account_id = "test-account-1"
      end
    end

    def render_error(status, message)
      render json: { error: message }, status: status
    end
  end
end
