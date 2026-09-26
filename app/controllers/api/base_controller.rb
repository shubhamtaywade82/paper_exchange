module Api
  class BaseController < ApplicationController
    include CursorPagination

    before_action :authenticate_api_key!
    before_action :set_account

    rescue_from CursorPagination::InvalidCursorError do |e|
      render_error(:bad_request, e.message)
    end

    private

    # Single-operator trust boundary (audit M2): every request under /api
    # must present the shared operator token via X-API-Key. Account
    # switching (X-Account-Id) happens WITHIN that authenticated boundary —
    # the account header is identity, not authorization. The comparison is
    # constant-time so the check cannot leak the key through response
    # timing. Production refuses to boot without the key set (see
    # config/initializers/api_authentication.rb).
    def authenticate_api_key!
      expected = ENV["PAPER_EXCHANGE_API_KEY"].to_s
      provided = request.headers["X-API-Key"].to_s
      return if !expected.empty? && ActiveSupport::SecurityUtils.secure_compare(provided, expected)

      render_error(:unauthorized, "Missing or invalid API key — set the X-API-Key header (PAPER_EXCHANGE_API_KEY on the server)")
    end

    def set_account
      @account_id = (request.headers["X-Account-Id"].presence ||
                     params[:account_id].presence ||
                     "default").to_s
    end

    def render_error(status, message)
      render json: { error: message }, status: status
    end
  end
end
