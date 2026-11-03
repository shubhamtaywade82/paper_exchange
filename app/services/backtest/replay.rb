module Backtest
  # The step-wise replay of one run. Both drivers use it:
  #
  #   * an external bot calls POST /api/backtest_runs/:id/advance, reads the bar,
  #     and places orders on the run's account (POST /api/orders). Those orders
  #     are queued, and they execute at the NEXT bar's open.
  #   * Backtest::Engine calls advance! in a loop and queues a built-in
  #     strategy's intents the same way.
  #
  # One advance processes one bar, in this order:
  #   1. the bar's open is the price: queued intents execute at it
  #   2. resting orders resolve against the bar (gaps, then range)
  #   3. liquidation, option expiry and orphaned exits are checked
  #   4. the bar's close is the mark, and the equity point is recorded
  #
  # Nothing in a step can see a later bar. A run finishes after its last bar
  # (or on request): resting orders are withdrawn, queued intents that have no
  # next open are cancelled, trades and metrics are stored, and the verdict is
  # computed against the run's declared benchmarks.
  class Replay
    class Invalid < StandardError; end
    class Conflict < StandardError; end

    # The bar that was processed, what it did, and where the account stands.
    Step = Struct.new(:bar, :next_bar_at, :equity, :position, :in_market, :submitted, :fills, :finished,
      keyword_init: true)

    ORDER_KINDS = %w[market bounded stop_loss].freeze

    class << self
      def run_for_account(account_id)
        return nil if account_id.blank?

        Run.find_by(account_id: account_id)
      end

      # Session for reads (balance, positions, orders) on a replay account: the
      # clock is the last processed bar, and the mark is its close.
      def with_session(run)
        session = session_at(run, run.replay_at || run.created_at)
        mark_last_close(run, session)
        Session.with(session) { yield session }
      end

      def session_at(run, at)
        session = Session.new(risk_gate: run.risk_gate)
        session.at = at
        session
      end

      def blank_diagnostics
        {
          "rejected_intents" => {},
          "rejected_intent_samples" => [],
          "risk_rejections" => 0,
          "cancelled_at_end" => 0,
          "unexecuted_intents" => 0,
          "open_position_at_end" => nil
        }
      end

      private

      def mark_last_close(run, session)
        return unless run.replay_at

        close = run.dataset.bars.where(bar_at: run.replay_at).pick(:close)
        session.set_mark(run.dataset.symbol, close) if close
      end
    end

    def initialize(run)
      @run = run
    end

    def contract
      @contract ||= Contract.from_dataset(@run.dataset)
    end

    # --- intents ------------------------------------------------------------

    # An order placed over the API on a replay account. It is validated now and
    # queued, and it executes at the next bar's open. Fill prices are set by the
    # replay, so an execution_price is refused.
    def queue_api_order!(payload)
      ensure_replayable!
      validate_contract_fields!(payload)
      if payload[:execution_price].present?
        raise Invalid, "execution_price is not accepted on a replay account: fills happen at the next bar's open, plus slippage_bps"
      end

      side = payload[:side].to_s.downcase
      raise Invalid, "side must be buy or sell" unless %w[buy sell].include?(side)

      reduce_only = ActiveModel::Type::Boolean.new.cast(payload[:reduce_only]) || false
      kind = (payload[:order_type].presence || payload[:order_kind].presence || "market").to_s.downcase
      raw = if reduce_only
        { action: "close", quantity: payload[:quantity] }
      else
        {
          action: side, order_kind: kind, price: payload[:price], trigger_price: payload[:trigger_price],
          stop_loss: payload[:stop_loss], take_profit: payload[:take_profit], quantity: payload[:quantity]
        }
      end
      normalized = validate_intent!(raw)

      Intent.create!(
        run: @run, source: "api", role: reduce_only ? "exit" : "entry", status: "queued",
        action: normalized[:action], side: side,
        order_kind: reduce_only ? nil : normalized[:order_kind], reduce_only: reduce_only,
        quantity: normalized[:quantity], price: normalized[:price], trigger_price: normalized[:trigger_price],
        stop_loss: normalized[:stop_loss], take_profit: normalized[:take_profit],
        leverage: leverage_from(payload), reason: reduce_only ? "api" : nil,
        client_order_id: payload[:client_order_id].presence, queued_at: queue_time
      )
    rescue ActiveRecord::RecordNotUnique
      raise Invalid, "client_order_id is already used in this run"
    end

    # Intents from a built-in strategy. They were decided at the last bar.
    def queue_engine_intents!(intents)
      ensure_replayable!
      intents.each do |raw|
        h = raw.to_h.symbolize_keys
        reduce_only = h[:action].to_s == "close"
        Intent.create!(
          run: @run, source: "engine", role: reduce_only ? "exit" : "entry", status: "queued",
          action: h[:action].to_s, side: reduce_only ? nil : (h[:action].to_s == "buy" ? "buy" : "sell"),
          order_kind: reduce_only ? nil : (h[:order_kind] || "market").to_s,
          reduce_only: reduce_only, quantity: Parse.positive_decimal(h[:quantity]),
          price: Parse.positive_decimal(h[:price]), trigger_price: Parse.positive_decimal(h[:trigger_price]),
          stop_loss: Parse.positive_decimal(h[:stop_loss]), take_profit: Parse.positive_decimal(h[:take_profit]),
          leverage: contract.leverage_allowed? ? @run.leverage : 1, reason: h[:tag].presence,
          queued_at: queue_time
        )
      end
    end

    def count_unexecuted!(count)
      return if count.zero?

      diagnostics = @run.diagnostics.deep_dup
      diagnostics["unexecuted_intents"] = diagnostics.fetch("unexecuted_intents", 0) + count
      @run.update!(diagnostics: diagnostics)
    end

    # --- stepping -----------------------------------------------------------

    # Processes the next bar and returns a Step, or nil when the dataset has no
    # bar after the replay position. The lock makes two concurrent advances
    # serialize, so no bar is ever processed twice.
    def advance!
      @run.with_lock do
        raise Conflict, "run is #{@run.status}; it accepts no more bars" unless @run.replayable?

        RunManager.upsert_account!(@run) unless Account.exists?(account_id: @run.account_id)
        bar = next_bar
        bar ? step_bar(bar) : nil
      end
    rescue OrderManager::ExecutionError, UnsupportedScenario => e
      # The step rolled back, so the account is as it was before this bar. The run
      # cannot continue safely (an unprotected position, or an unmodelled
      # settlement), so it is failed, and the reason is stored for the bot to read.
      RunManager.fail!(@run, e)
      raise
    end

    # Ends the replay now. Remaining bars are not processed.
    def finish!(reason: "requested")
      @run.with_lock do
        raise Conflict, "run is #{@run.status}; it is already finished" unless @run.replayable?

        last = last_processed_bar
        session = self.class.session_at(@run, @run.replay_at || @run.created_at)
        session.set_mark(contract.symbol, last.close) if last
        Session.with(session) do
          manager = build_manager(session, diagnostics: diagnostics_hash)
          finish_within_session!(manager, session, reason: reason, last_close: last&.close)
        end
      end
      @run
    end

    private

    def step_bar(dataset_bar)
      bar = to_candle(dataset_bar)
      session = self.class.session_at(@run, bar.bar_at)
      diagnostics = diagnostics_hash
      manager = build_manager(session, diagnostics: diagnostics)

      Session.with(session) do
        session.set_mark(contract.symbol, bar.open)
        manager.begin_bar(bar)
        held_at_open = !manager.current_position.nil?

        submitted = manager.submit_queued
        manager.fill_resting
        manager.check_liquidation
        manager.enforce_expiry
        manager.reconcile_flat!

        session.set_mark(contract.symbol, bar.close)
        equity = Equity.now(account_id: @run.account_id, symbol: contract.symbol)
        position = manager.current_position
        in_market = held_at_open || !position.nil? || manager.traded_this_bar?
        fills = fills_at(bar.bar_at)

        @run.equity_points.create!(bar_at: bar.bar_at, equity: equity, in_market: in_market)
        @run.update!(
          status: "running", replay_at: bar.bar_at, bars_processed: @run.bars_processed + 1,
          diagnostics: diagnostics, started_at: @run.started_at || Time.current
        )

        next_bar_at = next_bar_time_after(bar.bar_at)
        finished = next_bar_at.nil?
        finish_within_session!(manager, session, reason: "end_of_data", last_close: bar.close) if finished

        Step.new(
          bar: bar, next_bar_at: next_bar_at, equity: equity, position: position,
          in_market: in_market, submitted: submitted, fills: fills, finished: finished
        )
      end
    end

    def finish_within_session!(manager, session, reason:, last_close:)
      manager.finalize!
      diagnostics = manager.diagnostics
      position = manager.current_position
      diagnostics["open_position_at_end"] = position && {
        "side" => position.side,
        "quantity" => position.quantity.to_s("F"),
        "avg_price" => position.avg_price.to_s("F"),
        "unrealized_pnl" => Equity.position_pnl(position, session.mark(contract.symbol)).to_s("F")
      }
      diagnostics["finished_reason"] = reason
      Ledger::Ledger.refresh_cached_equity!(@run.account_id)

      trades = build_trades(manager)
      points = @run.equity_points.order(:bar_at).pluck(:bar_at, :equity, :in_market)
                 .map { |at, equity, in_market| [ at, equity, in_market ? 1 : 0 ] }
      first_close = @run.dataset.bars.order(:bar_at).pick(:close)
      metrics = MetricsCalculator.compute(
        trades: trades,
        equity_points: points,
        initial_capital: @run.initial_capital,
        buy_and_hold_return_pct: buy_and_hold_pct(first_close, last_close),
        periods_per_year: Timeframe.periods_per_year(@run.dataset.timeframe, contract.instrument_type)
      )
      now = Time.current

      Run.transaction do
        Trade.insert_all(trades.map { |trade| trade_row(trade, now) }) if trades.any?
        @run.update!(
          status: "completed",
          metrics: metrics,
          verdict: Verdict.call(benchmarks: @run.benchmarks, metrics: metrics),
          diagnostics: diagnostics,
          completed_at: now
        )
      end
    end

    def build_trades(manager)
      seconds = Timeframe.seconds(@run.dataset.timeframe)
      TradeJournal.build(account_id: @run.account_id, exit_reasons: manager.exit_reasons)
        .sort_by { |trade| [ trade[:exit_at], trade[:entry_order_id] ] }
        .each_with_index
        .map do |trade, index|
          trade.merge(sequence: index + 1, bars_held: ((trade[:exit_at] - trade[:entry_at]) / seconds).round)
        end
    end

    def trade_row(trade, now)
      {
        backtest_run_id: @run.id,
        sequence: trade[:sequence],
        symbol: trade[:symbol],
        instrument_type: trade[:instrument_type],
        option_type: trade[:option_type],
        strike_price: trade[:strike_price],
        expiry_date: trade[:expiry_date],
        direction: trade[:direction],
        quantity: trade[:quantity],
        entry_at: trade[:entry_at],
        entry_price: trade[:entry_price],
        exit_at: trade[:exit_at],
        exit_price: trade[:exit_price],
        gross_pnl: trade[:gross_pnl],
        commission: trade[:commission],
        net_pnl: trade[:net_pnl],
        return_pct: trade[:return_pct],
        bars_held: trade[:bars_held],
        exit_reason: trade[:exit_reason],
        entry_order_id: trade[:entry_order_id],
        exit_order_id: trade[:exit_order_id],
        created_at: now,
        updated_at: now
      }
    end

    def buy_and_hold_pct(first_close, last_close)
      return nil if first_close.nil? || last_close.nil? || !first_close.positive?

      ((last_close / first_close - 1) * 100).to_f.round(8)
    end

    def build_manager(session, diagnostics:)
      OrderManager.new(
        run: @run,
        exchange: ::Exchange::PaperExchange.new(account_id: @run.account_id),
        contract: contract,
        diagnostics: diagnostics
      )
    end

    def diagnostics_hash
      self.class.blank_diagnostics.merge((@run.diagnostics || {}).deep_dup)
    end

    # The fills booked at one bar. Only that bar's orders are looked up, so the
    # cost of a step does not grow with the length of the run.
    def fills_at(bar_at)
      trades = ::PaperExchange::PaperTrade.joins(:paper_order).includes(:paper_order)
        .where(paper_exchange_orders: { account_id: @run.account_id }, traded_at: bar_at)
        .order(:id).to_a
      return [] if trades.empty?

      reasons = Intent.where(paper_order_id: trades.map { |trade| trade.paper_order.id })
        .pluck(:paper_order_id, :role, :reason).index_by(&:first)
      trades.map do |trade|
        order = trade.paper_order
        _id, role, reason = reasons[order.id]
        {
          paper_order_id: order.id,
          side: trade.side,
          quantity: trade.quantity.to_f,
          price: trade.price.to_f,
          commission: trade.total_charges.to_f,
          role: role,
          reason: reason
        }
      end
    end

    def next_bar
      scope = @run.dataset.bars.order(:bar_at)
      scope = scope.where("bar_at > ?", @run.replay_at) if @run.replay_at
      row = scope.first
      row && to_candle(row)
    end

    def next_bar_time_after(at)
      @run.dataset.bars.where("bar_at > ?", at).order(:bar_at).pick(:bar_at)
    end

    def last_processed_bar
      return nil unless @run.replay_at

      row = @run.dataset.bars.find_by(bar_at: @run.replay_at)
      row && to_candle(row)
    end

    def to_candle(row)
      Candle.new(row.bar_at, row.open, row.high, row.low, row.close, row.volume)
    end

    # The time a queued intent was placed at: the last processed bar, or the
    # dataset's first bar before any bar has been processed.
    def queue_time
      @run.replay_at || @run.dataset.bars.minimum(:bar_at)
    end

    def ensure_replayable!
      raise Conflict, "run is #{@run.status}; it accepts no more orders" unless @run.replayable?
    end

    def validate_contract_fields!(payload)
      symbol = payload[:symbol].to_s.strip.upcase
      raise Invalid, "symbol must be #{contract.symbol} on this run" unless symbol == contract.symbol
      instrument = payload[:instrument_type].presence&.to_s&.upcase
      if instrument && instrument != contract.instrument_type
        raise Invalid, "instrument_type must be #{contract.instrument_type} on this run"
      end
    end

    def validate_intent!(raw)
      IntentValidator.call(raw, contract: contract, at: queue_time, lot_size: @run.lot_size)
    rescue IntentValidator::Invalid => e
      raise Invalid, e.message
    end

    def leverage_from(payload)
      return 1 unless contract.leverage_allowed?

      leverage = Integer(payload[:leverage].presence || @run.leverage, exception: false)
      raise Invalid, "leverage must be an integer between 1 and 100" unless leverage&.between?(1, 100)

      leverage
    end
  end
end
