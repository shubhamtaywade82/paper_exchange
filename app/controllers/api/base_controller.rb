module Api
  class BaseController < ApplicationController
    before_action :set_account

    private

    def set_account
      @account_id = (request.headers["X-Account-Id"].presence || params[:account_id].presence || "default").to_s
    end

    def render_error(status, message)
      render json: { error: message }, status: status
    end
  end
end
