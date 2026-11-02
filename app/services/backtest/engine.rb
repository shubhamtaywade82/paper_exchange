module Backtest
  # Runs one simulation: walks the dataset bar by bar, lets the strategy decide
  # at each close, executes those decisions at the next open through the
  # exchange, and persists the result.
  #
  # Timing contract, applied to every bar in this order:
  #   1. marks and book = the bar's open
  #   2. orders decided at the previous close are submitted (fill at the open)
  #   3. resting orders are resolved against the bar (gap at the open, then range)
  #   4. liquidation check, expiry check, orphaned exits cancelled
  #   5. marks = the bar's close; equity is recorded
  #   6. the strategy decides from this closed bar; its orders wait for step 2
  #      of the next bar
  #
  # Ledger::Ledger.refresh_cached_equity! runs inside the simulation session.
  # It reads marks, and outside the session it would read the live feed.
  class Engine
    LOOKBACK = 500
    BATCH_SIZE = 1_000

    class Invalid < StandardError; end

    Series = Struct.new(:points, :bars, :first_close, :last_close, :unexecuted, keyword_init: true)

    def initialize(run)
      @run = run
    end

    def call
      raise Invalid, "run #{@run.id} is #{@run.status}; only running runs can execute" unless @run.running?

      dataset = @run.dataset
      contract = Contract.from_dataset(dataset)
      strategy = Strategies.build(@run.strategy_key, @run.strategy_params, contract: contract)
      session = Session.new(risk_gate: @run.risk_gate)

      RunManager.clear_account!(@run)
      exchange = ::Exchange::PaperExchange.new(account_id: @run.account_id)
      manager = OrderManager.new(run: @run, exchange: exchange, contract: contract, session: session)

      series = simulate(contract, strategy, manager, session)
      trades = build_trades(manager, dataset)
      persist!(series, trades, manager, dataset, contract, session)
    end

    private

    def simulate(contract, strategy, manager, session)
      series = Series.new(points: [], bars: 0, first_close: nil, last_close: nil, unexecuted: 0)
      history = []
      pending = []

      Session.with(session) do
        each_bar do |bar, next_bar_at|
          session.at = bar.bar_at
          session.set_mark(contract.symbol, bar.open)
          manager.begin_bar(bar)
          held_at_open = !manager.current_position.nil?
          manager.submit(pending)
          pending = []
          manager.fill_resting
          manager.check_liquidation
          manager.enforce_expiry
          manager.reconcile_flat!
          session.set_mark(contract.symbol, bar.close)

          equity = Equity.now(account_id: @run.account_id, symbol: contract.symbol)
          position = manager.current_position
          in_market = held_at_open || !position.nil? || manager.traded_this_bar?
          series.points << [ bar.bar_at, equity, in_market ? 1 : 0 ]
          series.bars += 1
          series.first_close ||= bar.close
          series.last_close = bar.close

          history << bar
          history.shift if history.size > LOOKBACK

          context = Strategies::Base::StrategyContext.new(
            bar: bar, index: series.bars - 1, history: history, position: position,
            equity: equity, next_bar_at: next_bar_at, contract: contract
          )
          pending = strategy.on_bar(context)
        end

        manager.finalize!
        Ledger::Ledger.refresh_cached_equity!(@run.account_id)
      end

      series.unexecuted = pending.size
      series
    end

    # Streams bars in batches and yields each bar with the next bar's open
    # time. The next time is needed only for the strategy's signal window.
    def each_bar
      return enum_for(:each_bar) unless block_given?

      stream = candle_stream
      current = next_candle(stream)
      while current
        following = next_candle(stream)
        yield current, following&.bar_at
        current = following
      end
    end

    def candle_stream
      Enumerator.new do |yielder|
        cursor = nil
        loop do
          scope = @run.dataset.bars.order(:bar_at).limit(BATCH_SIZE)
          scope = scope.where("backtest_bars.bar_at > ?", cursor) if cursor
          rows = scope.pluck(:bar_at, :open, :high, :low, :close, :volume)
          break if rows.empty?

          rows.each { |row| yielder << Candle.new(*row) }
          cursor = rows.last[0]
        end
      end
    end

    def next_candle(stream)
      stream.next
    rescue StopIteration
      nil
    end

    def build_trades(manager, dataset)
      seconds = Timeframe.seconds(dataset.timeframe)
      journal = TradeJournal.build(account_id: @run.account_id, exit_reasons: manager.exit_reasons)
      journal
        .sort_by { |trade| [ trade[:exit_at], trade[:entry_order_id] ] }
        .each_with_index
        .map do |trade, index|
          trade.merge(
            sequence: index + 1,
            bars_held: ((trade[:exit_at] - trade[:entry_at]) / seconds).round
          )
        end
    end

    def persist!(series, trades, manager, dataset, contract, session)
      metrics = MetricsCalculator.compute(
        trades: trades,
        equity_points: series.points,
        initial_capital: @run.initial_capital,
        buy_and_hold_return_pct: buy_and_hold_pct(series),
        periods_per_year: Timeframe.periods_per_year(dataset.timeframe, contract.instrument_type)
      )
      now = Time.current

      Run.transaction do
        Trade.insert_all(trades.map { |trade| trade_row(trade, now) }) if trades.any?
        @run.update!(
          status: "completed",
          bars_processed: series.bars,
          metrics: metrics,
          equity_curve: series.points.map { |at, equity, in_market| [ at.iso8601(6), equity.to_s("F"), in_market ] },
          diagnostics: diagnostics(manager, series, contract, session),
          completed_at: now
        )
      end
      @run
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

    def buy_and_hold_pct(series)
      return nil if series.first_close.nil? || !series.first_close.positive?

      ((series.last_close / series.first_close - 1) * 100).to_f.round(8)
    end

    def diagnostics(manager, series, contract, session)
      position = manager.current_position
      open_position = position && {
        side: position.side,
        quantity: position.quantity.to_s("F"),
        avg_price: position.avg_price.to_s("F"),
        unrealized_pnl: Equity.position_pnl(position, session.mark(contract.symbol)).to_s("F")
      }
      manager.diagnostics.merge(
        unexecuted_intents: series.unexecuted,
        open_position_at_end: open_position
      )
    end
  end
end
