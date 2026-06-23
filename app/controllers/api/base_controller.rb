module Api
  class BaseController < ApplicationController
    before_action :set_account

    private

    def set_account
      @account_id = request.headers["X-Account-Id"].presence || params[:account_id].presence || "default"
      # In production, authenticate and derive account from token/JWT
    end

    def render_error(status, message)
      render json: { error: message }, status: status
    end
  end
end
