module Api
  class OrdersController < BaseController
    before_action :set_order, only: %i[show destroy]

    def index
      # Audit N6 (T5.4): keyset pagination on (placed_at, id) DESC — see
      # Api::CursorPagination for the envelope and cursor contract.
      orders, next_cursor = paginate(::PaperExchange::PaperOrder.where(account_id: @account_id), :placed_at)
      render json: { data: orders.map { |o| order_json(o) }, next_cursor: next_cursor }
    end

    def show
      render json: order_json(@order)
    end

    def create
      order_raw = params[:order] || params
      received = order_raw.permit(:symbol, :side, :quantity, :order_type, :type, :instrument_type, :option_type, :strike_price, :expiry_date, :ltp, :price, :trigger_price, :leverage, :margin_type, :client_order_id, :execution_price, :reduce_only, :stop_loss, :take_profit, context: {})

      run = Backtest::Replay.run_for_account(@account_id)
      return create_replay_order(run, received.to_unsafe_h.symbolize_keys) if run

      if received[:stop_loss].present? || received[:take_profit].present?
        return render_error(:unprocessable_content,
          "stop_loss/take_profit on an order are set on backtest replay accounts; on live accounts use /api/positions/:id/protections")
      end

      received[:account_id] = @account_id
      received[:order_kind] = (received.delete(:order_type) || received.delete(:type) || "market").to_s.downcase
      received[:side] = received[:side].to_s.downcase
      received[:instrument_type] = (received[:instrument_type].presence || "CRYPTO_PERPETUAL").to_s.upcase
      received = received.to_unsafe_h.symbolize_keys
      exchange = Exchange::PaperExchange.new(account_id: @account_id)
      order = exchange.submit_order(received)
      render json: order_json(order), status: :created
    rescue Exchange::OrderValidationError => e
      render_error(:unprocessable_content, e.message)
    rescue Exchange::PaperExchange::RiskCheckFailedError => e
      render_error(:unprocessable_content, e.message)
    rescue ArgumentError => e
      render_error(:bad_request, e.message)
    rescue Ledger::InsufficientMarginError => e
      render_error(:payment_required, e.message)
    rescue => e
      Rails.logger.error("[OrdersController#create] #{e.class}: #{e.message}")
      render_error(:internal_server_error, "Internal error")
    end

    def destroy
      # P1-5 fix: the service returns the committed, reloaded order instance
      # from inside the transaction — render THAT, not the stale @order
      # loaded by set_order before the cancel. Previously the response could
      # show status "open" while the order was actually "cancelled" in the DB.
      cancelled_order = exchange.cancel_order(@order.id)
      render json: order_json(cancelled_order)
    rescue ::PaperExchange::PaperOrder::StateError => e
      # Double-cancel or cancelling a terminal order — the current state
      # conflicts with the requested transition (audit S1).
      render_error(:conflict, e.message)
    end

    private

    # On a replay account the order is queued and executes at the next bar's
    # open. The response is 202, because nothing has filled yet.
    def create_replay_order(run, payload)
      intent = Backtest::Replay.new(run).queue_api_order!(payload)
      render json: replay_intent_json(intent, run), status: :accepted
    rescue Backtest::Replay::Invalid => e
      render_error(:unprocessable_content, e.message)
    rescue Backtest::Replay::Conflict => e
      render_error(:conflict, e.message)
    end

    def replay_intent_json(intent, run)
      {
        id: intent.id,
        status: intent.status,
        client_order_id: intent.client_order_id,
        symbol: run.dataset.symbol,
        side: intent.side,
        quantity: intent.quantity&.to_f,
        order_type: intent.order_kind,
        reduce_only: intent.reduce_only,
        price: intent.price&.to_f,
        trigger_price: intent.trigger_price&.to_f,
        stop_loss: intent.stop_loss&.to_f,
        take_profit: intent.take_profit&.to_f,
        executes_at: "next bar open after #{run.replay_at&.iso8601 || 'the first bar'}"
      }
    end

    def set_order
      @order = ::PaperExchange::PaperOrder.lock.find_by(id: params[:id], account_id: @account_id)
      render_error(:not_found, "Order not found") unless @order
    end

    def order_json(order)
      {
        id: order.id,
        client_order_id: order.client_order_id,
        symbol: order.symbol,
        side: order.side,
        quantity: order.quantity,
        filled_quantity: order.filled_quantity,
        remaining_quantity: order.remaining_quantity,
        order_type: order.order_kind,
        status: order.status,
        price: order.price,
        trigger_price: order.trigger_price,
        instrument_type: order.instrument_type,
        option_type: order.option_type,
        strike_price: order.strike_price,
        expiry_date: order.expiry_date,
        leverage: order.leverage,
        margin_type: order.margin_type,
        locked_margin: order.locked_margin,
        placed_at: order.placed_at,
        updated_at: order.updated_at
      }
    end
  end
end
