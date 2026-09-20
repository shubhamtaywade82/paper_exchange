module Api
  class OrdersController < BaseController
    before_action :set_order, only: %i[show destroy]

    def index
      orders = ::PaperExchange::PaperOrder.where(account_id: @account_id)
        .order(placed_at: :desc)
        .limit(200)
      render json: orders.map { |o| order_json(o) }
    end

    def show
      render json: order_json(@order)
    end

    def create
      order_raw = params[:order] || params
      received = order_raw.permit(:symbol, :side, :quantity, :order_type, :type, :instrument_type, :option_type, :strike_price, :expiry_date, :ltp, :price, :trigger_price, :leverage, :margin_type, :client_order_id, :execution_price, context: {})
      received[:account_id] = @account_id
      received[:order_kind] = (received.delete(:order_type) || received.delete(:type) || "market").to_s.downcase
      received[:side] = received[:side].to_s.downcase
      received[:instrument_type] = (received[:instrument_type].presence || "CRYPTO_PERPETUAL").to_s.upcase
      # OrderValidator raises OrderValidationError on bad input; the rescue
      # below turns that into a 400.
      received = Exchange::OrderValidator.call(received)

      exchange = Exchange::PaperExchange.new(account_id: @account_id)
      order = exchange.submit_order(received)
      render json: order_json(order), status: :created
    rescue Exchange::OrderValidationError => e
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
      exchange = Exchange::PaperExchange.new(account_id: @account_id)
      exchange.cancel_order(@order.id)
      render json: order_json(@order)
    end

    private

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
