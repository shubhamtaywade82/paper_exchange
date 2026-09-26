module Exchange
  class PaperExchange
    # Raised when a reduce_only order finds no position on the opposite side to
    # reduce. LiquidationJob treats it as "someone already closed this".
    # OrderValidationError lives in order_validator.rb, so Zeitwerk can only
    # find it once OrderValidator has been referenced.
    OrderValidator
    class PositionGoneError < OrderValidationError; end

    attr_reader :account_id

    # Keys accepted by OrderValidator's schema that are NOT PaperOrder
    # columns (ltp/execution_price/client_order_id-adjacent inputs used only
    # to derive a reference price or for idempotency, and context, used only
    # for Strategy::Signal). Passing these straight into PaperOrder.new would
    # raise ActiveRecord::UnknownAttributeError.
    ORDER_COLUMN_KEYS = %i[
      symbol side quantity order_kind instrument_type option_type strike_price
      expiry_date price trigger_price leverage margin_type client_order_id
    ].freeze

    def initialize(account_id:)
      @account_id = account_id
      @books = {}
      @mutex = Mutex.new
      @order_book = OrderBook.new(@mutex, @books)
      @slippage = SlippageEngine.new
      @latency = LatencyEngine.new
      @matching = MatchingEngine.new(order_book: @order_book, slippage: @slippage, latency: @latency)
      @fill_engine = FillEngine.new(slippage: @slippage)
    end

    # Raised when the risk gate rejects an order. Carries the rejection
    # symbols so submit_order's post-rollback rescue can persist the
    # *_REJECTED RiskEvent rows (audit M5) — persisting them inside the
    # doomed transaction only rolled them back with it.
    class RiskCheckFailedError < StandardError
      attr_reader :rejections

      def initialize(rejections)
        @rejections = Array(rejections)
        super("Risk check failed: #{@rejections.join(', ')}")
      end
    end

    # `internal:` (and `reduce_only`, which can only shrink exposure) skips the
    # margin lock and risk gate. Used by LiquidationJob
    # to force-close a position whose liquidation price has been breached — the
    # account is by definition underwater at that point, so a fresh margin
    # lock would always raise InsufficientMarginError and the close order
    # would be rejected by the very engine that triggered it (B3 deadlock).
    # The lock-then-unlock dance in the normal path is a no-op for closing
    # orders anyway (MarginEngine.sync_position! releases the position's own
    # initial_margin once it goes flat).
    def submit_order(order_attrs = nil, internal: false, **extra_attrs)
      attrs_in = if order_attrs.is_a?(Hash)
        order_attrs.merge(extra_attrs)
      else
        extra_attrs
      end
      internal = attrs_in.delete(:internal) if attrs_in.key?(:internal)

      client_order_id = attrs_in[:client_order_id].presence
      if client_order_id
        existing = ::PaperExchange::PaperOrder.find_by(account_id: account_id, client_order_id: client_order_id)
        return existing if existing
      end

      attrs = Exchange::OrderValidator.call(attrs_in)
      attrs = clamp_to_position(attrs) if attrs[:reduce_only]
      skip_gates = internal || attrs[:reduce_only]

      signal = Strategy::Signal.new(
        account_id: account_id,
        symbol: attrs[:symbol],
        side: attrs[:side],
        quantity: attrs[:quantity],
        order_kind: attrs[:order_kind],
        instrument_type: attrs[:instrument_type],
        option_type: attrs[:option_type],
        strike_price: attrs[:strike_price],
        expiry_date: attrs[:expiry_date],
        ltp: attrs[:ltp],
        context: attrs.fetch(:context, {})
      )

      order = ::PaperExchange::PaperOrder.new(
        attrs.slice(*ORDER_COLUMN_KEYS).merge(account_id: account_id, placed_at: Time.current)
      )
      begin
        order.save!
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        if client_order_id && (replay = ::PaperExchange::PaperOrder.find_by(account_id: account_id, client_order_id: client_order_id))
          return replay
        end
        raise
      end

      # H1: lock_margin! + risk + fill are atomic. If anything inside raises,
      # the whole transaction rolls back — including the margin lock — and
      # the outer rescue persists :rejected on the order. No manual
      # release_order_margin! needed on the rejection path: the rollback
      # already undid it.
      ::PaperExchange::PaperOrder.transaction do
        order.open!
        clamp_order_to_locked_position!(order) if attrs[:reduce_only]

        if attrs[:execution_price].present?
          execution_price = attrs[:execution_price].to_f
          @order_book.apply_snapshot(order.symbol, bid: execution_price, ask: execution_price, ltp: execution_price)
          MarketData::MarkPriceStore.set(order.symbol, execution_price)
        end

        unless skip_gates
          reference_price = (order.price || attrs[:execution_price] || attrs[:ltp]).to_f
          required_margin = order.required_margin(reference_price)
          Ledger::MarginLedger.lock_margin!(
            account_id: account_id,
            amount: required_margin,
            reference_id: order.id.to_s,
            payload: { order_id: order.id, symbol: order.symbol, reason: "order_margin_lock" }
          )
          order.update_column(:locked_margin, required_margin)

          result = Risk::RiskManager.evaluate(account_id: account_id, signal: signal)
          _passed, rejected = result
          if Array(rejected).any? { |sym| sym.to_s.end_with?("_REJECTED") }
            raise RiskCheckFailedError, Array(rejected)
          end
        end

        result = @matching.execute(order)
        fill_qty, fill_price = result if result.is_a?(Array) && result[0].is_a?(Numeric)

        if fill_qty && fill_qty.positive?
          exact_price = (attrs[:execution_price].presence || order.price)&.to_f
          fill_qty, fill_price, trade = @fill_engine.fill(
            order,
            market_snapshot: @order_book.snapshot(order.symbol),
            instrument_type: order.instrument_type,
            quantity: fill_qty,
            price: exact_price
          )
          if trade
            position = PositionManager.apply!(
              account_id: account_id,
              symbol: order.symbol,
              side: order.side,
              quantity: fill_qty,
              avg_price: fill_price,
              leverage: order.leverage,
              margin_type: order.margin_type,
              instrument_type: order.instrument_type,
              option_type: order.option_type,
              strike_price: order.strike_price,
              expiry_date: order.expiry_date
            )
            trade.update!(paper_position: position)
            release_order_margin!(order) unless skip_gates
            MarginEngine.sync_position!(position, account_id: account_id)
            Ledger::Ledger.record_trade(account_id: account_id, trade: trade)

            if order.instrument_type == "CRYPTO_PERPETUAL"
              if trade.total_charges.to_f > 0
                Ledger::MarginLedger.deduct_fee!(
                  account_id: account_id,
                  amount: trade.total_charges,
                  reference_id: trade.id.to_s,
                  payload: { trade_id: trade.id, symbol: order.symbol, reason: "trade_fee" }
                )
              end
              if position.last_realized_pnl && !position.last_realized_pnl.zero?
                Ledger::MarginLedger.credit_realized_pnl!(
                  account_id: account_id,
                  amount: position.last_realized_pnl,
                  reference_id: trade.id.to_s,
                  payload: { trade_id: trade.id, symbol: order.symbol, reason: "realized_pnl" }
                )
              end
              Ledger::Ledger.refresh_cached_equity!(account_id)
            end
            MarketData::MarkPriceStore.set(order.symbol, fill_price)
          end
          order.filled!
        end
      end

      order
    rescue ArgumentError
      raise
    rescue RiskCheckFailedError => e
      order.rejected!(e.message) if order&.persisted?
      # This rescue runs AFTER the fill transaction has rolled back, so
      # these rows persist — the rejection history /api/risk_events exists
      # to serve (audit M5: they used to be created inside the transaction
      # and vanish with the rollback).
      e.rejections.each do |event|
        RiskEvent.create!(
          account_id: account_id,
          event_type: event,
          details: { signal: signal&.to_h, rejection: e.message }
        )
      end
      raise
    rescue => e
      order.rejected!(e.message) if order&.persisted?
      raise
    end

    def cancel_order(order_id)
      order = ::PaperExchange::PaperOrder.find(order_id)
      release_order_margin!(order)
      order.cancel!
    end

    def expire_order(order_id)
      order = ::PaperExchange::PaperOrder.find(order_id)
      release_order_margin!(order)
      order.expired!
    end

    def market_event(event)
      if event.respond_to?(:symbol) && event.respond_to?(:bid) && event.respond_to?(:ask)
        @order_book.apply_snapshot(
          event.symbol,
          bid: event.bid,
          ask: event.ask,
          ltp: event.ltp,
          depth: event.to_h[:depth],
          timestamp: event.timestamp
        )
      end
    end

    def order_book(symbol)
      @order_book.snapshot(symbol)
    end

    private

    # Cheap first check, run before any order row exists so an obviously bad
    # reduce-only order is a plain 422 that leaves nothing behind. It reads the
    # position WITHOUT a lock, so it is advisory only: the guarantee that a
    # reduce-only order never grows or flips a position comes from
    # clamp_order_to_locked_position! inside the fill transaction.
    def clamp_to_position(attrs)
      position = reducible_position(attrs)
      attrs.merge(quantity: [ attrs[:quantity], position.quantity ].min)
    end

    # Authoritative check: re-reads the position under a row lock right before
    # the fill. Anything that closed or shrank it since clamp_to_position ran
    # (LiquidationJob, another reduce-only order) is seen here, and PositionManager
    # only runs after this lock is taken, so nothing can slip in before the fill.
    def clamp_order_to_locked_position!(order)
      position = reducible_position(order.slice(:symbol, :side, :instrument_type, :option_type, :strike_price, :expiry_date).symbolize_keys, lock: true)
      live_quantity = [ order.quantity, position.quantity ].min
      order.update_column(:quantity, live_quantity) if live_quantity != order.quantity
    end

    def reducible_position(attrs, lock: false)
      contract = attrs.slice(:symbol, :instrument_type, :option_type, :strike_price, :expiry_date)
      scope = ::PaperExchange::PaperPosition.where(account_id: account_id).where.not(quantity: 0)
      scope = scope.lock if lock
      position = scope.find_by(contract)
      closing_side = position&.long? ? "sell" : "buy"
      unless position && attrs[:side] == closing_side
        raise PositionGoneError, "reduce_only #{attrs[:side]} #{attrs[:symbol]} rejected: no open position on the opposite side to reduce (position gone)"
      end

      position
    end

    # Releases whatever margin is still held against this order back to the
    # account's available balance. Called once the order's own lock has
    # either been superseded by a position-level lock (fill — see
    # MarginEngine.sync_position!) or is no longer needed (reject, cancel,
    # expiry).
    def release_order_margin!(order)
      return if order.locked_margin.to_f.zero?

      Ledger::MarginLedger.unlock_margin!(
        account_id: order.account_id,
        amount: order.locked_margin,
        reference_id: order.id.to_s,
        payload: { order_id: order.id, symbol: order.symbol, reason: "order_margin_release" }
      )
      order.update_column(:locked_margin, 0)
    end
  end
end
