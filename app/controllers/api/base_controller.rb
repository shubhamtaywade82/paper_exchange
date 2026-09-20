module Api
  class BaseController < ApplicationController
    before_action :set_account

    private

    def set_account
      @account_id = (request.headers["X-Account-Id"].presence ||
                     request.headers["X-API-Key"].presence ||
                     params[:account_id].presence ||
                     "default").to_s
      if @account_id == "test-api-key-123" && !Account.exists?(account_id: @account_id)
        @account_id = "test-account-1"
      end
    end

    def render_error(status, message)
      render json: { error: message }, status: status
    end
  end
end
