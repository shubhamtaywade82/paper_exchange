module Api
  class BaseController < ApplicationController
    include CursorPagination

    before_action :authenticate_api_key!
    before_action :set_account
    around_action :with_replay_session

    # Live market-data writes are global: they move every account's marks. A
    # replay account moves its own prices, only through POST /advance.
    REPLAY_GLOBAL_WRITES = %w[mark_prices funding_events market_events market_structure].freeze

    # Global API contract (prod-hardening NEW-6): every unhandled exception
    # used to bubble to Rails' default ActionController::API 500 handler,
    # which in production renders an HTML error page — not the documented
    # { "error": "..." } JSON shape the agent expects. Centralising the
    # rescue here guarantees a consistent JSON envelope for every endpoint,
    # logs the failure with the request id for forensic correlation, and
    # keeps a 404 for not-found lookups instead of a 500. Local `rescue`
    # clauses in individual actions (e.g. OrdersController#create) still
    # take precedence — this only catches what they let through.
    #
    # ORDERING NOTE: ActiveSupport::Rescuable checks handlers most-recently-
    # registered first (each rescue_from unshifts onto the handler list).
    # The general StandardError handler MUST be registered FIRST so it lands
    # at the end of the list and is only reached when no more specific handler
    # matches — otherwise it would shadow InvalidCursorError / ParameterMissing
    # / RecordNotFound and turn their 400/404 responses into 500s.
    rescue_from StandardError do |e|
      # In test env, let exceptions propagate so specs can assert on them
      # (e.g. AccountsController#reset's atomic-rollback spec expects the
      # RuntimeError to surface). In production/dev, render the documented
      # JSON envelope so the agent never gets an HTML error page.
      raise e if Rails.env.test?

      Rails.logger.error("[#{self.class.name}] #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      render_error(:internal_server_error, "Internal error")
    end

    rescue_from ActiveRecord::RecordNotFound do
      render_error(:not_found, "Resource not found")
    end

    rescue_from ActionController::ParameterMissing do |e|
      render_error(:bad_request, e.message)
    end

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

    # A request on a replay account runs inside that run's simulation session:
    # the account's clock is the last processed bar, and its mark is that bar's
    # close. Live feeds cannot be posted against a replay account, because the
    # replay alone sets its prices.
    def with_replay_session
      run = Backtest::Replay.run_for_account(@account_id)
      return yield unless run

      if request.post? && REPLAY_GLOBAL_WRITES.include?(controller_name)
        return render_error(:unprocessable_content,
          "#{controller_name.tr('_', ' ')} writes global market state; a replay account moves its own prices with POST /api/backtest_runs/:id/advance")
      end

      Backtest::Replay.with_session(run) { yield }
    end

    def render_error(status, message)
      render json: { error: message }, status: status
    end
  end
end
