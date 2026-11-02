module Backtest
  # Validates one order intent (from a strategy or a signal replay) before the
  # engine turns it into an exchange order.
  #
  # Rules encoded here, from the trading standards:
  #   * options are bought, never written: a sell that opens a position on an
  #     option contract is rejected
  #   * every opening order carries a protective stop-loss
  #   * quantity is a whole multiple of the run's lot size
  #   * nothing opens on a contract after its expiry date
  #
  # Returns a normalized Hash or raises Invalid with a short reason code. The
  # reason code is what the run's diagnostics count.
  module IntentValidator
    class Invalid < StandardError; end

    ACTIONS = %w[buy sell close].freeze
    KINDS = %w[market bounded stop_loss].freeze

    module_function

    def call(raw, contract:, at:, lot_size:)
      h = raw.to_h.symbolize_keys
      action = h[:action].to_s
      raise Invalid, "unknown_action" unless ACTIONS.include?(action)

      tag = h[:tag].to_s.presence
      return { action: "close", tag: tag } if action == "close"

      side = action == "buy" ? "buy" : "sell"
      raise Invalid, "options_buy_only" if contract.option? && side == "sell"
      raise Invalid, "contract_expired" if contract.expired_at?(at)

      kind = (h[:order_kind].presence || "market").to_s
      raise Invalid, "unknown_order_kind" unless KINDS.include?(kind)

      price = Parse.positive_decimal(h[:price])
      trigger_price = Parse.positive_decimal(h[:trigger_price])
      raise Invalid, "bounded_requires_price" if kind == "bounded" && price.nil?
      raise Invalid, "stop_loss_requires_trigger_price" if kind == "stop_loss" && trigger_price.nil?

      stop_loss = Parse.positive_decimal(h[:stop_loss])
      raise Invalid, "stop_loss_required" if stop_loss.nil?

      take_profit = Parse.positive_decimal(h[:take_profit])
      quantity = Parse.positive_decimal(h[:quantity])
      raise Invalid, "quantity_not_lot_multiple" if quantity && !lot_multiple?(quantity, lot_size)

      {
        action: action,
        side: side,
        order_kind: kind,
        price: price,
        trigger_price: trigger_price,
        stop_loss: stop_loss,
        take_profit: take_profit,
        quantity: quantity,
        tag: tag
      }
    end

    def lot_multiple?(quantity, lot_size)
      (quantity / lot_size).frac.zero?
    end
  end
end
