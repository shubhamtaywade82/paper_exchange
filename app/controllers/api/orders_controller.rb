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
      received = params[:order].permit(:symbol, :side, :quantity, :order_type, :instrument_type, :option_type, :strike_price, :expiry_date, :ltp, :price, :trigger_price)
      received[:account_id] = @account_id
      received[:order_kind] = received.delete(:order_type) if received.key?(:order_type)
      valid, errors = Exchange::OrderValidator.call(received)
      raise "Invalid order: #{errors.inspect}" unless valid

      exchange = Exchange::PaperExchange.new(account_id: @account_id)
      order = exchange.submit_order(received)
      render json: order_json(order), status: :created
    rescue => e
      render_error(:unprocessable_entity, e.message)
    end

    def order_params
      params.require(:order).permit(:symbol, :side, :quantity, :order_type, :instrument_type, :option_type, :strike_price, :expiry_date, :ltp, :price, :trigger_price)
    rescue ActionController::ParameterMissing => e
      render_error(:bad_request, e.message)
      {}
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

    def order_params
      params.require(:order).permit(:symbol, :side, :quantity, :order_type, :instrument_type, :option_type, :strike_price, :expiry_date, :ltp, :price, :trigger_price)
    rescue ActionController::ParameterMissing => e
      render_error(:bad_request, e.message)
    end

    def order_json(order)
      {
        id: order.id,
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
        placed_at: order.placed_at,
        updated_at: order.updated_at
      }
    end
  end
end
