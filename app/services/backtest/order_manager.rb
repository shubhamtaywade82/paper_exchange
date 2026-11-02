module Backtest
  # Turns strategy intents into exchange orders and resolves resting orders
  # against each bar.
  #
  # Every fill goes through Exchange::PaperExchange: submit_order for orders
  # that fill at the open, and match_and_fill for resting orders. Margin lock,
  # risk gate, position netting, brokerage and ledger postings are therefore
  # the live code path, not a simulation of it.
  #
  # Protective exits are owned here. When an entry fills, its stop-loss (and
  # optional take-profit) are placed as reduce-only orders. When the position
  # goes flat, any remaining exits are cancelled (OCO behaviour). A stop-loss
  # that cannot be placed fails the run instead of being skipped, because an
  # unprotected position is not an outcome the engine is allowed to report.
  class OrderManager
    class ExecutionError < StandardError; end

    REJECTION_SAMPLE_LIMIT = 50
    MAX_FILL_PASSES = 10_000

    # order id => the exit reason, for every reduce-only fill. The trade
    # journal reads it to label each closed trade.
    attr_reader :exit_reasons

    def initialize(run:, exchange:, contract:, session:)
      @run = run
      @exchange = exchange
      @contract = contract
      @session = session
      @account_id = run.account_id
      @slippage_bps = run.slippage_bps
      @lot_size = run.lot_size
      @roles = {}
      @exit_reasons = {}
      @rejections = Hash.new(0)
      @rejection_samples = []
      @risk_rejections = 0
      @cancelled_at_end = 0
      @sequence = 0
      @bar = nil
    end

    def begin_bar(bar)
      @bar = bar
      @fills_this_bar = 0
      reset_book!
    end

    # True when at least one order filled during the current bar. A trade that
    # opens and closes inside one bar still counts as exposure for that bar.
    def traded_this_bar?
      @fills_this_bar.to_i.positive?
    end

    def submit(intents)
      intents.each { |raw| submit_intent(raw) }
    end

    # Resolves every open order against the current bar. Stops are considered
    # before limits (adverse-first). A fill can place new exits, so passes repeat
    # until nothing more fills.
    def fill_resting
      passes = 0
      loop do
        passes += 1
        raise ExecutionError, "resting-order resolution did not converge" if passes > MAX_FILL_PASSES

        progressed = false
        resting_orders.each do |order|
          order.reload
          next unless order.status == "open"

          price = resting_fill_price(order)
          next if price.nil?

          fill_resting_order(order, price)
          progressed = true
        end
        break unless progressed
      end
    end

    def check_liquidation
      position = current_position
      return unless position&.leveraged?
      return unless position.liquidated?(extreme_price(position))

      cancel_exit_orders("liquidation")
      liquidation = BigDecimal(position.liquidation_price.to_s)
      # A gap through the liquidation price fills at the open, as a stop does.
      fill_price = position.long? ? [ @bar.open, liquidation ].min : [ @bar.open, liquidation ].max
      submit_order(
        side: closing_side(position), kind: "market", quantity: position.quantity,
        role: :liquidation, reason: "liquidation", reduce_only: true, fixed_price: fill_price
      )
    end

    # Option contracts are not settled inside a backtest. A position still open
    # after its expiry date fails the run, because the result would otherwise
    # be wrong.
    def enforce_expiry
      return if @contract.expiry_date.nil? || @bar.bar_at.to_date <= @contract.expiry_date
      return if current_position.nil?

      raise UnsupportedScenario,
        "#{@contract.symbol} expired on #{@contract.expiry_date} with an open position; " \
        "expiry settlement is not modelled in backtests"
    end

    def reconcile_flat!
      return if current_position

      resting_orders.each do |order|
        cancel(order, "position_flat") if meta_for(order)[:reduce_only]
      end
    end

    def finalize!
      resting_orders.each do |order|
        cancel(order, "end_of_data")
        @cancelled_at_end += 1
      end
    end

    def current_position
      ::PaperExchange::PaperPosition
        .where(account_id: @account_id, symbol: @contract.symbol, instrument_type: @contract.instrument_type)
        .where.not(quantity: 0)
        .first
    end

    def diagnostics
      {
        rejected_intents: @rejections.sort.to_h,
        rejected_intent_samples: @rejection_samples,
        risk_rejections: @risk_rejections,
        cancelled_at_end: @cancelled_at_end
      }
    end

    private

    def submit_intent(raw)
      intent = IntentValidator.call(raw, contract: @contract, at: @bar.bar_at, lot_size: @lot_size)
      intent[:action] == "close" ? submit_close : submit_entry(intent)
    rescue IntentValidator::Invalid => e
      reject(e.message)
    end

    def submit_close
      position = current_position
      return reject("no_position_to_close") unless position

      submit_order(
        side: closing_side(position), kind: "market", quantity: position.quantity,
        role: :exit, reason: "signal", reduce_only: true
      )
    end

    def submit_entry(intent)
      side = intent[:side]
      position = current_position
      if position
        same_side = (side == "buy") == position.long?
        return reject(same_side ? "pyramiding_disabled" : "opposite_position_open")
      end
      return reject("entry_already_pending") if pending_entry?

      reference = intent[:price] || intent[:trigger_price] || @bar.open
      return reject("stop_loss_wrong_side") unless stop_on_protective_side?(side, intent[:stop_loss], reference)
      if intent[:take_profit] && !target_on_profit_side?(side, intent[:take_profit], reference)
        return reject("take_profit_wrong_side")
      end

      quantity = intent[:quantity] || sizing_quantity(reference, intent[:stop_loss])
      return reject("insufficient_quantity") unless quantity&.positive?

      submit_order(
        side: side, kind: intent[:order_kind], quantity: quantity,
        price: intent[:price], trigger_price: intent[:trigger_price],
        role: :entry, reason: nil, reduce_only: false,
        stop_loss: intent[:stop_loss], take_profit: intent[:take_profit]
      )
    end

    def stop_on_protective_side?(side, stop, reference)
      side == "buy" ? stop < reference : stop > reference
    end

    def target_on_profit_side?(side, target, reference)
      side == "buy" ? target > reference : target < reference
    end

    def sizing_quantity(reference, stop_loss)
      sizing = @run.sizing.to_h
      case sizing["type"]
      when "fixed"
        Parse.positive_decimal(sizing["quantity"])
      when "percent_of_equity"
        percent = Parse.positive_decimal(sizing["percent"])
        equity = Equity.now(account_id: @account_id, symbol: @contract.symbol)
        floor_to_lot(equity * percent / 100 / reference)
      when "risk_percent"
        # Max loss per trade: a stop-out at `stop_loss` loses risk_percent of equity.
        # Gaps past the stop and commissions can make the realized loss larger.
        risk = Parse.positive_decimal(sizing["risk_percent"])
        distance = (reference - stop_loss).abs
        return nil if distance.zero?

        equity = Equity.now(account_id: @account_id, symbol: @contract.symbol)
        floor_to_lot(equity * risk / 100 / distance)
      end
    end

    def floor_to_lot(raw)
      (raw / @lot_size).floor * @lot_size
    end

    # Places one order. An order that is already through its level at the open
    # is submitted with an explicit execution_price, so it fills at the open and
    # never relies on the book. Any other order is submitted as a resting order,
    # and fill_resting resolves it against the bar.
    def submit_order(side:, kind:, quantity:, role:, reason:, reduce_only:,
      price: nil, trigger_price: nil, stop_loss: nil, take_profit: nil, fixed_price: nil)
      reset_book!
      immediate = fixed_price || FillCalculator.at_open(
        kind: kind, side: side, price: price, trigger_price: trigger_price,
        open: @bar.open, slippage_bps: @slippage_bps
      )

      attrs = {
        account_id: @account_id,
        side: side,
        quantity: quantity,
        order_kind: kind,
        price: price,
        trigger_price: trigger_price,
        leverage: (@run.leverage if @contract.leverage_allowed?),
        client_order_id: next_client_order_id,
        execution_price: immediate,
        reduce_only: (true if reduce_only)
      }.merge(@contract.order_attributes).compact

      order = @exchange.submit_order(attrs)
      remember(order, role: role, reason: reason, reduce_only: reduce_only, stop_loss: stop_loss, take_profit: take_profit)

      case order.status
      when "filled" then on_filled(order)
      when "rejected" then fail_or_reject(role, "exchange_rejected", order.rejection_reason)
      end
      order
    rescue Exchange::PaperExchange::RiskCheckFailedError => e
      @risk_rejections += 1
      fail_or_reject(role, "risk_gate", e.rejections.join(", "))
      nil
    rescue Ledger::InsufficientMarginError => e
      fail_or_reject(role, "insufficient_margin", e.message)
      nil
    rescue Exchange::OrderValidationError, ActiveRecord::RecordInvalid => e
      fail_or_reject(role, "order_invalid", e.message)
      nil
    end

    def fail_or_reject(role, code, detail)
      return reject(code, detail) if role == :entry

      raise ExecutionError, "#{role} order could not be placed (#{code}): #{detail}"
    end

    def on_filled(order)
      @fills_this_bar = @fills_this_bar.to_i + 1
      meta = meta_for(order)
      @exit_reasons[order.id] = meta[:reason] if meta[:reduce_only]
      attach_brackets(order, meta) if meta[:role] == :entry
      reconcile_flat!
    end

    # Places the protective legs of a filled entry. If one leg is already
    # through the open, only that leg is placed: the position it protects is
    # already closed by the gap, and the other leg would be orphaned.
    def attach_brackets(entry, meta)
      exit_side = entry.side == "buy" ? "sell" : "buy"
      legs = []
      if meta[:stop_loss]
        legs << { role: :stop, kind: "stop_loss", price: nil, trigger_price: meta[:stop_loss], reason: "stop_loss" }
      end
      if meta[:take_profit]
        legs << { role: :take_profit, kind: "bounded", price: meta[:take_profit], trigger_price: nil, reason: "take_profit" }
      end

      through_open = legs.find do |leg|
        FillCalculator.at_open(
          kind: leg[:kind], side: exit_side, price: leg[:price], trigger_price: leg[:trigger_price],
          open: @bar.open, slippage_bps: @slippage_bps
        )
      end

      if through_open
        place_leg(through_open, exit_side, entry.quantity)
      else
        legs.each { |leg| place_leg(leg, exit_side, entry.quantity) }
      end
    end

    def place_leg(leg, exit_side, quantity)
      submit_order(
        side: exit_side, kind: leg[:kind], quantity: quantity,
        price: leg[:price], trigger_price: leg[:trigger_price],
        role: leg[:role], reason: leg[:reason], reduce_only: true
      )
    end

    def resting_orders
      ::PaperExchange::PaperOrder
        .where(account_id: @account_id, status: "open")
        .order(order_kind: :desc, placed_at: :asc, id: :asc)
        .to_a
    end

    def resting_fill_price(order)
      FillCalculator.at_open(
        kind: order.order_kind, side: order.side, price: order.price,
        trigger_price: order.trigger_price, open: @bar.open, slippage_bps: @slippage_bps
      ) || FillCalculator.intrabar(
        kind: order.order_kind, side: order.side, price: order.price,
        trigger_price: order.trigger_price, high: @bar.high, low: @bar.low,
        slippage_bps: @slippage_bps
      )
    end

    def fill_resting_order(order, price)
      meta = meta_for(order)
      if meta[:reduce_only]
        live = current_position&.quantity || 0
        if live.zero?
          cancel(order, "position_flat")
          return
        end
        # A reduce-only order can never grow or flip the position.
        order.update_column(:quantity, live) if order.quantity > live
      end

      filled = @exchange.match_and_fill(order, price)
      on_filled(filled)
    end

    def pending_entry?
      resting_orders.any? { |order| meta_for(order)[:role] == :entry }
    end

    def cancel_exit_orders(reason)
      resting_orders.each { |order| cancel(order, reason) if meta_for(order)[:reduce_only] }
    end

    def cancel(order, _reason)
      @exchange.cancel_order(order.id)
    end

    def remember(order, role:, reason:, reduce_only:, stop_loss:, take_profit:)
      @roles[order.id] = {
        role: role, reason: reason, reduce_only: reduce_only,
        stop_loss: stop_loss, take_profit: take_profit
      }
    end

    def meta_for(order)
      @roles.fetch(order.id) { raise ExecutionError, "order #{order.id} was not placed by this run" }
    end

    def reset_book!
      @exchange.market_event(
        MarketData::MarketEvent.new(
          symbol: @contract.symbol, bid: @bar.open, ask: @bar.open, ltp: @bar.open, timestamp: @bar.bar_at
        )
      )
    end

    def closing_side(position)
      position.long? ? "sell" : "buy"
    end

    def extreme_price(position)
      position.long? ? @bar.low : @bar.high
    end

    def next_client_order_id
      @sequence += 1
      "bt-#{@run.id}-#{@sequence}"
    end

    def reject(code, detail = nil)
      @rejections[code] += 1
      if @rejection_samples.size < REJECTION_SAMPLE_LIMIT
        @rejection_samples << { at: @bar&.bar_at&.iso8601, code: code, detail: detail }.compact
      end
      nil
    end
  end
end
