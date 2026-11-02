module Api
  # Backtest runs: create a run, execute it, read its metrics, trades, orders
  # and equity curve, reset it, or delete it.
  #
  # Status codes: 201 created, 202 accepted (queued for execution), 409
  # conflict (wrong state for the action, e.g. executing a run that already
  # completed without a reset), 422 invalid definition.
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
      run = Backtest::Run.create!(attrs)
      render json: run_json(run), status: :created
    rescue Backtest::RunValidator::Invalid => e
      render json: { error: "invalid backtest run", details: e.errors }, status: :unprocessable_content
    rescue ActiveRecord::RecordInvalid => e
      render_error(:unprocessable_content, e.record.errors.full_messages.join(", "))
    end

    def execute
      return render_error(:conflict, "run is #{@run.status}; reset it before executing again") unless @run.pending?

      BacktestRunJob.perform_later(@run.id)
      render json: run_json(@run), status: :accepted
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

    # Every bar's mark-to-market equity, oldest first.
    def equity
      curve = @run.equity_curve.map do |at, equity, in_market|
        { at: at, equity: equity.to_f, in_market: in_market == 1 }
      end
      render json: { data: curve }
    end

    private

    def set_run
      @run = Backtest::Run.find_by(id: params[:id])
      render_error(:not_found, "Backtest run not found") unless @run
    end

    def run_json(run)
      {
        id: run.id,
        name: run.name,
        status: run.status,
        account_id: run.account_id,
        dataset_id: run.backtest_dataset_id,
        strategy: { key: run.strategy_key, params: run.strategy_params },
        config: {
          initial_capital: run.initial_capital.to_f,
          leverage: run.leverage,
          sizing: run.sizing,
          slippage_bps: run.slippage_bps.to_f,
          lot_size: run.lot_size.to_f,
          risk_gate: run.risk_gate
        },
        bars_processed: run.bars_processed,
        metrics: run.metrics,
        diagnostics: run.diagnostics,
        failure_reason: run.failure_reason,
        started_at: run.started_at,
        completed_at: run.completed_at,
        created_at: run.created_at
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
