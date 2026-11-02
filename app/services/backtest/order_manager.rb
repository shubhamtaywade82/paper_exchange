module Backtest
  # Executes a run's order intents against one bar, through PaperExchange.
  #
  # State lives in Backtest::Intent rows, not in this object. A bot can place
  # an order between two bars, and the next step loads the intent again. Every
  # fill goes through Exchange::PaperExchange: submit_order for orders that
  # fill at the open, and match_and_fill for resting orders. So margin lock,
  # risk gate, position netting, brokerage and ledger are the live code path.
  #
  # Protective exits are owned here. When an entry fills, its stop-loss (and
  # optional take-profit) are placed as reduce-only legs. When the position
  # goes flat, remaining exits are cancelled (OCO). A protective leg that cannot
  # be placed fails the run, rather than leaving a position unprotected.
  class OrderManager
    class ExecutionError < StandardError; end

    PROTECTIVE_ROLES = %w[stop take_profit liquidation].freeze
    REJECTION_SAMPLE_LIMIT = 50
    MAX_FILL_PASSES = 10_000

    attr_reader :diagnostics

    # diagnostics is the run's diagnostics Hash (string keys), mutated in place.
    def initialize(run:, exchange:, contract:, diagnostics:)
      @run = run
      @exchange = exchange
      @contract = contract
      @account_id = run.account_id
      @slippage_bps = run.slippage_bps
      @lot_size = run.lot_size
      @diagnostics = diagnostics
      # Counters are read back from jsonb, which has no default for missing keys.
      @diagnostics["rejected_intents"] = Hash.new(0).merge(@diagnostics["rejected_intents"] || {})
      @bar = nil
      @fills_this_bar = 0
    end

    def begin_bar(bar)
      @bar = bar
      @fills_this_bar = 0
      reset_book!
    end

    # True when at least one order filled during the current bar. A trade that
    # opens and closes inside one bar still counts as exposure for that bar.
    def traded_this_bar?
      @fills_this_bar.positive?
    end

    # Executes every queued intent of the run, oldest first, at the current bar's
    # open. Returns the intents, so the caller can report what happened.
    def submit_queued
      queued = Intent.where(backtest_run_id: @run.id, status: "queued").order(:id).to_a
      queued.each { |intent| process_intent(intent) }
      queued.map(&:reload)
    end

    # Resolves every open order against the current bar. Stops are considered
    # before limits (adverse-first). A fill can place new legs, so passes repeat
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
        role: "liquidation", reason: "liquidation", reduce_only: true, fixed_price: fill_price,
        source: "liquidation"
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
        intent = intent_for(order)
        cancel(order, intent, "position_flat") if intent.reduce_only
      end
    end

    # End of data: withdraw resting orders, and withdraw queued intents that
    # have no next open to execute on.
    def finalize!
      resting_orders.each do |order|
        cancel(order, intent_for(order), "end_of_data")
        @diagnostics["cancelled_at_end"] += 1
      end
      Intent.where(backtest_run_id: @run.id, status: "queued").find_each do |intent|
        intent.update!(status: "cancelled", note: "no_next_open")
        @diagnostics["unexecuted_intents"] += 1
      end
    end

    def current_position
      ::PaperExchange::PaperPosition
        .where(account_id: @account_id, symbol: @contract.symbol, instrument_type: @contract.instrument_type)
        .where.not(quantity: 0)
        .first
    end

    # Exit reasons by paper order id, for the trade journal.
    def exit_reasons
      Intent.where(backtest_run_id: @run.id, reduce_only: true).where.not(paper_order_id: nil)
        .pluck(:paper_order_id, :reason).to_h
    end

    private

    def process_intent(intent)
      raw = {
        action: intent.action, order_kind: intent.order_kind, price: intent.price,
        trigger_price: intent.trigger_price, stop_loss: intent.stop_loss,
        take_profit: intent.take_profit, quantity: intent.quantity, tag: intent.reason
      }
      normalized = IntentValidator.call(raw, contract: @contract, at: @bar.bar_at, lot_size: @lot_size)
      if normalized[:action] == "close"
        submit_close(intent, normalized)
      else
        submit_entry(intent, normalized)
      end
    rescue IntentValidator::Invalid => e
      reject_intent(intent, e.message)
    end

    def submit_close(intent, normalized)
      position = current_position
      return reject_intent(intent, "no_position_to_close") unless position
      # A reduce-only order must close the position: a buy against a long would open a new one.
      if intent.side.present? && intent.side != closing_side(position)
        return reject_intent(intent, "reduce_only_wrong_side")
      end

      quantity = [ normalized[:quantity] || position.quantity, position.quantity ].min
      submit_order(
        record: intent, side: closing_side(position), kind: "market", quantity: quantity,
        role: "exit", reason: intent.reason || "signal", reduce_only: true
      )
    end

    def submit_entry(intent, normalized)
      side = normalized[:side]
      position = current_position
      if position
        same_side = (side == "buy") == position.long?
        return reject_intent(intent, same_side ? "pyramiding_disabled" : "opposite_position_open")
      end
      return reject_intent(intent, "entry_already_pending") if pending_entry?

      reference = normalized[:price] || normalized[:trigger_price] || @bar.open
      return reject_intent(intent, "stop_loss_wrong_side") unless stop_on_protective_side?(side, normalized[:stop_loss], reference)
      if normalized[:take_profit] && !target_on_profit_side?(side, normalized[:take_profit], reference)
        return reject_intent(intent, "take_profit_wrong_side")
      end

      quantity = normalized[:quantity] || sizing_quantity(reference, normalized[:stop_loss])
      return reject_intent(intent, "insufficient_quantity") unless quantity&.positive?

      submit_order(
        record: intent, side: side, kind: normalized[:order_kind], quantity: quantity,
        price: normalized[:price], trigger_price: normalized[:trigger_price],
        role: "entry", reason: intent.reason, reduce_only: false,
        stop_loss: normalized[:stop_loss], take_profit: normalized[:take_profit]
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

    # Places one order for an intent, or for a leg or liquidation created by the
    # replay. An order already through its level at the open is submitted with
    # an explicit execution_price, so it fills at the open and never relies on
    # the book. Any other order rests, and fill_resting resolves it against the bar.
    def submit_order(record: nil, side:, kind:, quantity:, role:, reason:, reduce_only:,
      price: nil, trigger_price: nil, stop_loss: nil, take_profit: nil, fixed_price: nil,
      source: nil, parent: nil)
      record ||= Intent.create!(
        run: @run, source: source || "engine", role: role, status: "queued",
        action: reduce_only ? "close" : (side == "buy" ? "buy" : "sell"), side: side,
        order_kind: kind, reduce_only: reduce_only, quantity: quantity, price: price,
        trigger_price: trigger_price, stop_loss: stop_loss, take_profit: take_profit,
        leverage: leverage_for_order, reason: reason, parent_intent: parent, queued_at: @bar.bar_at
      )
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
        leverage: (record.leverage if @contract.leverage_allowed?),
        client_order_id: record.client_order_id || "bt-#{@run.id}-#{record.id}",
        execution_price: immediate,
        reduce_only: (true if reduce_only)
      }.merge(@contract.order_attributes).compact

      order = @exchange.submit_order(attrs)
      if order.status == "rejected"
        return fail_submission(record, "exchange_rejected", order.rejection_reason)
      end

      record.update!(paper_order_id: order.id, status: "submitted", submitted_at: @bar.bar_at)
      on_filled(order, record) if order.status == "filled"
      order
    rescue Exchange::PaperExchange::RiskCheckFailedError => e
      @diagnostics["risk_rejections"] += 1
      fail_submission(record, "risk_gate", e.rejections.join(", "))
    rescue Ledger::InsufficientMarginError => e
      fail_submission(record, "insufficient_margin", e.message)
    rescue Exchange::OrderValidationError, ActiveRecord::RecordInvalid => e
      fail_submission(record, "order_invalid", e.message)
    end

    # A protective leg or a liquidation that cannot be placed fails the run. An
    # entry or an exit request is rejected and recorded.
    def fail_submission(record, code, detail)
      if PROTECTIVE_ROLES.include?(record.role)
        record.update!(status: "rejected", rejection_reason: "#{code}: #{detail}")
        raise ExecutionError, "#{record.role} order could not be placed (#{code}): #{detail}"
      end

      reject_intent(record, code, detail)
    end

    def on_filled(order, record)
      @fills_this_bar += 1
      attach_brackets(record, order) if record.role == "entry"
      reconcile_flat!
    end

    # Places the protective legs of a filled entry. If one leg is already
    # through the open, only that leg is placed: the position it protects is
    # already closed by the gap, and the other leg would be orphaned.
    def attach_brackets(entry, entry_order)
      exit_side = entry_order.side == "buy" ? "sell" : "buy"
      legs = []
      if entry.stop_loss
        legs << { role: "stop", kind: "stop_loss", price: nil, trigger_price: entry.stop_loss, reason: "stop_loss" }
      end
      if entry.take_profit
        legs << { role: "take_profit", kind: "bounded", price: entry.take_profit, trigger_price: nil, reason: "take_profit" }
      end

      through_open = legs.find do |leg|
        FillCalculator.at_open(
          kind: leg[:kind], side: exit_side, price: leg[:price], trigger_price: leg[:trigger_price],
          open: @bar.open, slippage_bps: @slippage_bps
        )
      end

      (through_open ? [ through_open ] : legs).each do |leg|
        submit_order(
          source: "bracket", parent: entry, side: exit_side, kind: leg[:kind], quantity: entry_order.quantity,
          price: leg[:price], trigger_price: leg[:trigger_price], role: leg[:role],
          reason: leg[:reason], reduce_only: true
        )
      end
    end

    def resting_orders
      ::PaperExchange::PaperOrder
        .where(account_id: @account_id, status: "open")
        .order(order_kind: :desc, placed_at: :asc, id: :asc)
        .to_a
    end

    def intent_for(order)
      Intent.find_by(paper_order_id: order.id) ||
        raise(ExecutionError, "paper order #{order.id} is not tracked by run #{@run.id}")
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
      intent = intent_for(order)
      if intent.reduce_only
        live = current_position&.quantity || 0
        if live.zero?
          cancel(order, intent, "position_flat")
          return
        end
        # A reduce-only order can never grow or flip the position.
        order.update_column(:quantity, live) if order.quantity > live
      end

      filled = @exchange.match_and_fill(order, price)
      on_filled(filled, intent)
    end

    def pending_entry?
      resting_orders.any? { |order| intent_for(order).role == "entry" }
    end

    def cancel_exit_orders(reason)
      resting_orders.each do |order|
        intent = intent_for(order)
        cancel(order, intent, reason) if intent.reduce_only
      end
    end

    def cancel(order, intent, note)
      @exchange.cancel_order(order.id)
      intent.update!(status: "cancelled", note: note)
    end

    def reject_intent(intent, code, detail = nil)
      intent.update!(status: "rejected", rejection_reason: [ code, detail ].compact.join(": "))
      @diagnostics["rejected_intents"][code] += 1
      samples = @diagnostics["rejected_intent_samples"]
      if samples.size < REJECTION_SAMPLE_LIMIT
        samples << { "at" => @bar&.bar_at&.iso8601, "code" => code, "detail" => detail }.compact
      end
      nil
    end

    def leverage_for_order
      @contract.leverage_allowed? ? @run.leverage : 1
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
  end
end
