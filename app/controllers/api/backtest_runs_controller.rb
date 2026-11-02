module Api
  # Backtest runs. Two drivers, one replay:
  #
  #   external  a bot drives the run: POST /advance returns the next bar, the
  #             bot decides, and its orders (POST /api/orders with the run's
  #             X-Account-Id) execute at the next bar's open
  #   engine    a built-in strategy decides; POST /execute runs it in the background
  #
  # Status codes: 201 created, 202 accepted, 409 wrong state for the action,
  # 422 invalid definition or order.
  class BacktestRunsController < BaseController
    before_action :set_run, except: %i[index create]

    def index
      runs, next_cursor = paginate(Backtest::Run.all, :created_at)
      render json: { data: runs.map { |r| run_json(r) }, next_cursor: next_cursor }
    end

    def show
      render json: run_json(@run)
    end

    def create
      attrs = Backtest::RunValidator.call(params.to_unsafe_h)
      run = Backtest::RunManager.create!(attrs)
      render json: run_json(run), status: :created
    rescue Backtest::RunValidator::Invalid => e
      render json: { error: "invalid backtest run", details: e.errors }, status: :unprocessable_content
    rescue ActiveRecord::RecordInvalid => e
      render_error(:unprocessable_content, e.record.errors.full_messages.join(", "))
    end

    def execute
      return render_error(:conflict, "external runs are driven over the API: POST /advance") if @run.external?
      return render_error(:conflict, "run is #{@run.status}; reset it before executing again") unless @run.pending?

      BacktestRunJob.perform_later(@run.id)
      render json: run_json(@run), status: :accepted
    end

    # Processes the next bar. The response carries the bar, what the replay
    # did with the queued orders at its open, the fills, and the account state.
    def advance
      return render_error(:conflict, "engine runs are driven by their strategy; use POST /execute") if @run.engine?

      step = Backtest::Replay.new(@run).advance!
      return render_error(:conflict, "no bar after the replay position; the run is finished") unless step

      render json: step_json(step)
    rescue Backtest::Replay::Conflict => e
      render_error(:conflict, e.message)
    end

    # Ends the replay now. Resting orders are withdrawn, and the trades, metrics
    # and verdict are stored.
    def finish
      run = Backtest::Replay.new(@run).finish!(reason: "requested")
      render json: run_json(run)
    rescue Backtest::Replay::Conflict => e
      render_error(:conflict, e.message)
    end

    def reset
      render json: run_json(Backtest::RunManager.reset!(@run))
    rescue Backtest::RunManager::Conflict => e
      render_error(:conflict, e.message)
    end

    def destroy
      Backtest::RunManager.destroy!(@run)
      head :no_content
    rescue Backtest::RunManager::Conflict => e
      render_error(:conflict, e.message)
    end

    # The bars the run has processed, oldest first. A bot that restarts reads
    # its history here. Bars after the replay position are never returned.
    def history
      return render json: { data: [], replay_at: nil } unless @run.replay_at

      limit = Integer(params[:limit], exception: false) || 500
      rows = @run.dataset.bars.where("bar_at <= ?", @run.replay_at)
        .order(bar_at: :desc).limit(limit.clamp(1, 2000)).to_a.reverse
      render json: { data: rows.map { |bar| candle_json(bar) }, replay_at: @run.replay_at }
    end

    def intents
      rows, next_cursor = paginate(@run.intents, :created_at)
      render json: { data: rows.map { |i| intent_json(i) }, next_cursor: next_cursor }
    end

    def trades
      rows, next_cursor = paginate(@run.trades, :entry_at)
      render json: { data: rows.map { |t| trade_json(t) }, next_cursor: next_cursor }
    end

    def orders
      rows, next_cursor = paginate(::PaperExchange::PaperOrder.where(account_id: @run.account_id), :placed_at)
      render json: { data: rows.map { |o| order_json(o) }, next_cursor: next_cursor }
    end

    def positions
      rows = ::PaperExchange::PaperPosition.where(account_id: @run.account_id).order(:id)
      render json: { data: rows.map { |p| position_json(p) } }
    end

    # Mark-to-market equity at every processed bar, oldest first.
    def equity
      points = @run.equity_points.order(:bar_at).pluck(:bar_at, :equity, :in_market)
      render json: {
        data: points.map { |at, equity, in_market| { at: at.iso8601(6), equity: equity.to_f, in_market: in_market } }
      }
    end

    private

    def set_run
      @run = Backtest::Run.find_by(id: params[:id])
      render_error(:not_found, "Backtest run not found") unless @run
    end

    def step_json(step)
      position = step.position
      {
        bar: candle_json(step.bar),
        bars_processed: @run.reload.bars_processed,
        equity: step.equity.to_f,
        in_market: step.in_market,
        position: position && {
          side: position.side,
          quantity: position.quantity.to_f,
          avg_price: position.avg_price.to_f,
          unrealized_pnl: Backtest::Equity.position_pnl(position, step.bar.close).to_f
        },
        submitted: step.submitted.map { |intent| intent_json(intent) },
        fills: step.fills,
        finished: step.finished,
        verdict: step.finished ? @run.verdict : nil
      }
    end

    def candle_json(bar)
      {
        bar_at: bar.bar_at.iso8601,
        open: bar.open.to_f,
        high: bar.high.to_f,
        low: bar.low.to_f,
        close: bar.close.to_f,
        volume: bar.volume.to_f
      }
    end

    def run_json(run)
      {
        id: run.id,
        name: run.name,
        mode: run.mode,
        status: run.status,
        account_id: run.account_id,
        dataset_id: run.backtest_dataset_id,
        symbol: run.dataset.symbol,
        strategy: { key: run.strategy_key, params: run.strategy_params },
        config: {
          initial_capital: run.initial_capital.to_f,
          leverage: run.leverage,
          sizing: run.sizing,
          slippage_bps: run.slippage_bps.to_f,
          lot_size: run.lot_size.to_f,
          risk_gate: run.risk_gate
        },
        manifest: run.manifest,
        benchmarks: run.benchmarks,
        verdict: run.verdict,
        bars_processed: run.bars_processed,
        replay_at: run.replay_at,
        metrics: run.metrics,
        diagnostics: run.diagnostics,
        failure_reason: run.failure_reason,
        started_at: run.started_at,
        completed_at: run.completed_at,
        created_at: run.created_at
      }
    end

    def intent_json(intent)
      {
        id: intent.id,
        status: intent.status,
        source: intent.source,
        role: intent.role,
        action: intent.action,
        side: intent.side,
        order_type: intent.order_kind,
        reduce_only: intent.reduce_only,
        quantity: intent.quantity&.to_f,
        price: intent.price&.to_f,
        trigger_price: intent.trigger_price&.to_f,
        stop_loss: intent.stop_loss&.to_f,
        take_profit: intent.take_profit&.to_f,
        reason: intent.reason,
        client_order_id: intent.client_order_id,
        paper_order_id: intent.paper_order_id,
        rejection_reason: intent.rejection_reason,
        note: intent.note,
        queued_at: intent.queued_at,
        submitted_at: intent.submitted_at
      }
    end

    def trade_json(trade)
      {
        id: trade.id,
        sequence: trade.sequence,
        symbol: trade.symbol,
        instrument_type: trade.instrument_type,
        option_type: trade.option_type,
        strike_price: trade.strike_price&.to_f,
        expiry_date: trade.expiry_date,
        direction: trade.direction,
        quantity: trade.quantity.to_f,
        entry_at: trade.entry_at,
        entry_price: trade.entry_price.to_f,
        exit_at: trade.exit_at,
        exit_price: trade.exit_price.to_f,
        gross_pnl: trade.gross_pnl.to_f,
        commission: trade.commission.to_f,
        net_pnl: trade.net_pnl.to_f,
        return_pct: trade.return_pct.to_f,
        bars_held: trade.bars_held,
        exit_reason: trade.exit_reason,
        entry_order_id: trade.entry_order_id,
        exit_order_id: trade.exit_order_id
      }
    end

    def order_json(order)
      {
        id: order.id,
        client_order_id: order.client_order_id,
        symbol: order.symbol,
        side: order.side,
        quantity: order.quantity.to_f,
        filled_quantity: order.filled_quantity.to_f,
        order_type: order.order_kind,
        status: order.status,
        price: order.price&.to_f,
        trigger_price: order.trigger_price&.to_f,
        rejection_reason: order.rejection_reason,
        placed_at: order.placed_at,
        filled_at: order.filled_at
      }
    end

    def position_json(position)
      {
        id: position.id,
        symbol: position.symbol,
        instrument_type: position.instrument_type,
        option_type: position.option_type,
        strike_price: position.strike_price&.to_f,
        expiry_date: position.expiry_date,
        side: position.side,
        quantity: position.quantity.to_f,
        avg_price: position.avg_price&.to_f,
        current_price: position.current_price&.to_f,
        initial_margin: position.initial_margin.to_f,
        liquidation_price: position.liquidation_price&.to_f
      }
    end
  end
end
