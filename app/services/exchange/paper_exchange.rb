module Exchange
  class PaperExchange
    # Raised when a reduce_only order finds no position on the opposite side to
    # reduce. LiquidationJob treats it as "someone already closed this".
    # OrderValidationError lives in order_validator.rb, so Zeitwerk can only
    # find it once OrderValidator has been referenced.
    OrderValidator
    class PositionGoneError < OrderValidationError; end
    # Raised when a cash-equity sell that is not reduce_only asks for more shares
    # than the account holds, after shares reserved by its open sell orders.
    # Cash equity is never sold short by this platform (no product flag exists to
    # permit intraday shorting).
    class InsufficientHoldingError < OrderValidationError; end

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
    #
    # `settlement_price:` is internal-only (OptionExpiryJob): the exact price a
    # forced close books at, which may be 0 for an option that expires out of
    # the money. execution_price cannot carry it — a client-facing field that
    # must stay > 0 — and without it the close would fill at whatever premium
    # the book last saw instead of the option's intrinsic value.
    def submit_order(order_attrs = nil, internal: false, settlement_price: nil, **extra_attrs)
      attrs_in = if order_attrs.is_a?(Hash)
        order_attrs.merge(extra_attrs)
      else
        extra_attrs
      end
      internal = attrs_in.delete(:internal) if attrs_in.key?(:internal)
      settlement_price = attrs_in.delete(:settlement_price) if attrs_in.key?(:settlement_price)
      if settlement_price && !internal
        raise ArgumentError, "settlement_price is only accepted on internal orders"
      end
      if settlement_price && (!settlement_price.to_f.finite? || settlement_price.to_f.negative?)
        raise ArgumentError, "settlement_price must be a finite number >= 0, got #{settlement_price.inspect}"
      end

      client_order_id = attrs_in[:client_order_id].presence
      if client_order_id
        existing = ::PaperExchange::PaperOrder.find_by(account_id: account_id, client_order_id: client_order_id)
        return existing if existing
      end

      attrs = Exchange::OrderValidator.call(attrs_in)
      Markets::OrderRules.validate!(attrs)
      attrs = clamp_to_position(attrs) if attrs[:reduce_only]
      skip_gates = internal || attrs[:reduce_only]

      # P1-2 fix: build ONE authoritative reference price before risk
      # evaluation. The margin validator and the margin lock must see the
      # same notional — previously the signal carried :ltp but not
      # :execution_price, so a market order with only execution_price had
      # zero notional in the risk gate (bypassing MAX_POSITION_VALUE) while
      # the actual margin lock used the real execution_price.
      # Try execution_price → explicit price → ltp → order book snapshot.
      reference_price = decimal(attrs[:execution_price] || attrs[:price] || attrs[:ltp])
      if reference_price <= 0
        # Fall back to the order book snapshot (set via market_event or a
        # prior fill) rather than raising — many test paths submit orders
        # without execution_price and expect the stub book to provide the
        # price. A truly missing price (no book either) will still surface
        # as a 0-notional order that the matching engine rejects.
        book = @order_book.snapshot(attrs[:symbol])
        reference_price = decimal(book&.dig(:ltp)) if reference_price <= 0 && book
      end

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
        ltp: reference_price,
        context: attrs.fetch(:context, {})
      )

      order = ::PaperExchange::PaperOrder.new(
        attrs.slice(*ORDER_COLUMN_KEYS).merge(account_id: account_id, placed_at: Backtest::Session.now, metadata: order_metadata(attrs))
      )
      begin
        ::PaperExchange::PaperOrder.transaction do
          assert_equity_holdings!(attrs) unless internal
          order.save!
        end
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

        if settlement_price
          pinned = decimal(settlement_price)
          @order_book.apply_snapshot(order.symbol, bid: pinned, ask: pinned, ltp: pinned)
        elsif attrs[:execution_price].present?
          execution_price = decimal(attrs[:execution_price])
          @order_book.apply_snapshot(order.symbol, bid: execution_price, ask: execution_price, ltp: execution_price)
        end

        unless skip_gates
          # P1-2: use the same reference_price the risk gate saw, not a
          # separately-computed value that could disagree. The old code
          # read (order.price || attrs[:execution_price] || attrs[:ltp])
          # here while the signal used attrs[:ltp] — a market order with
          # only execution_price passed the risk gate with zero notional
          # but locked the real margin here, creating an inconsistency.
          # The risk gate runs BEFORE the margin lock. MarginValidator compares
          # the order's margin with available_balance, and after lock_margin!
          # that balance already excludes this order's own margin. The old
          # order rejected any order needing more than half the free balance
          # (MARGIN_REJECTED on a 6,000 buy with 10,000 free). Nothing is
          # written before the gate, and the lock still sits inside the same
          # transaction, so a rejection leaves no state behind.
          required_margin = order.required_margin(reference_price)
          result = Risk::RiskManager.evaluate(account_id: account_id, signal: signal)
          _passed, rejected = result
          if Array(rejected).any? { |sym| sym.to_s.end_with?("_REJECTED") }
            # A cash shortfall keeps its documented status: 402 via
            # InsufficientMarginError (design.md §3), the same error the lock raises.
            available = Account.find_by(account_id: account_id)&.available_balance
            if Array(rejected).include?(:MARGIN_REJECTED) && available && available < required_margin
              raise Ledger::InsufficientMarginError,
                "account #{account_id} has #{available} available, needs #{required_margin}"
            end

            raise RiskCheckFailedError, Array(rejected)
          end

          Ledger::MarginLedger.lock_margin!(
            account_id: account_id,
            amount: required_margin,
            reference_id: order.id.to_s,
            payload: { order_id: order.id, symbol: order.symbol, reason: "order_margin_lock" }
          )
          order.update_column(:locked_margin, required_margin)
        end

        result = @matching.execute(order)
        fill_qty, fill_price = result if result.is_a?(Array) && result[0].is_a?(Numeric)

        if fill_qty && fill_qty.positive?
          exact_price = settlement_price ? decimal(settlement_price) : optional_decimal(attrs[:execution_price].presence || order.price)
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
              metadata: order.metadata,
              margin_type: order.margin_type,
              instrument_type: order.instrument_type,
              option_type: order.option_type,
              strike_price: order.strike_price,
              expiry_date: order.expiry_date
            )
            trade.update!(paper_position: position)
            release_order_margin!(order) unless skip_gates
            MarginEngine.sync_position!(position, account_id: account_id)
            # P0-1: pass realized_pnl explicitly so record_trade doesn't
            # depend on the position association being reloaded from DB.
            Ledger::Ledger.record_trade(account_id: account_id, trade: trade, realized_pnl: position.last_realized_pnl)

            if order.instrument_type == "CRYPTO_PERPETUAL"
              if trade.total_charges.positive?
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

    # P1-5 fix: the lock, state validation, status transition, and margin
    # release are all inside ONE transaction with consistent lock ordering.
    # Previously cancel_order did a locked read, then cancel! opened its own
    # transaction, and release_order_margin! was a third — a fill could race
    # between the locked read and the cancel transaction, and a failure in
    # margin release after the cancel committed left the account with locked
    # funds on a cancelled order. Now the order row is locked for the
    # duration of the entire operation.
    def cancel_order(order_id)
      ::PaperExchange::PaperOrder.transaction do
        order = ::PaperExchange::PaperOrder.lock.find_by!(id: order_id, account_id: account_id)
        order.cancel!
        release_order_margin!(order)
        order
      end
    end

    def expire_order(order_id)
      ::PaperExchange::PaperOrder.transaction do
        order = ::PaperExchange::PaperOrder.lock.find_by!(id: order_id, account_id: account_id)
        order.expired!
        release_order_margin!(order)
        order
      end
    end

    # Architecture alignment (target architecture §4): autonomous matching.
    # Called by the MatchingWorker when a market event makes an open order
    # executable. Fills the order at the given live fill_price (derived from
    # the QuoteStore's best bid/ask), bypassing the risk gate (margin was
    # already locked at submit time) and the matching engine's slippage
    # model (the fill price is the actual executable book price).
    #
    # The caller (MatchingWorker) holds the order row lock; this method
    # runs the fill-engine + position-manager + ledger sequence inside the
    # caller's transaction. Idempotent via the order's status guard — a
    # double fill attempt raises StateError (caught by the caller).
    def match_and_fill(order, fill_price)
      raise ::PaperExchange::PaperOrder::StateError, "order is not open" unless order.status == "open"

      @order_book.apply_snapshot(order.symbol, bid: fill_price, ask: fill_price, ltp: fill_price)

      fill_qty, actual_fill_price, trade = @fill_engine.fill(
        order,
        market_snapshot: @order_book.snapshot(order.symbol),
        instrument_type: order.instrument_type,
        quantity: order.remaining_quantity,
        price: fill_price
      )

      return nil unless trade

      position = PositionManager.apply!(
        account_id: account_id,
        symbol: order.symbol,
        side: order.side,
        quantity: fill_qty,
        avg_price: actual_fill_price,
        leverage: order.leverage,
        metadata: order.metadata,
        margin_type: order.margin_type,
        instrument_type: order.instrument_type,
        option_type: order.option_type,
        strike_price: order.strike_price,
        expiry_date: order.expiry_date
      )
      trade.update!(paper_position: position)
      release_order_margin!(order)
      MarginEngine.sync_position!(position, account_id: account_id)
      Ledger::Ledger.record_trade(account_id: account_id, trade: trade, realized_pnl: position.last_realized_pnl)

      if order.instrument_type == "CRYPTO_PERPETUAL"
        if trade.total_charges.positive?
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

      order.filled!
      order
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

    # Money from a client, a feed or a column, as an exact decimal. A blank value
    # is zero where a price is required, and nil where it is optional; an
    # unparseable value raises rather than becoming a guess.
    # #19: strategy attribution. The key comes from the order's `context`, as
    # the agent sends it. It is stored on the order and copied to the position
    # when the fill opens it.
    def order_metadata(attrs)
      context = attrs[:context]
      return {} unless context.is_a?(Hash)

      key = context[:strategy_key] || context["strategy_key"]
      key.present? ? { "strategy_key" => key.to_s } : {}
    end

    def decimal(value)
      return BigDecimal("0") if value.nil? || value.to_s.strip.empty?

      BigDecimal(value.to_s)
    end

    def optional_decimal(value)
      return nil if value.nil? || value.to_s.strip.empty?

      BigDecimal(value.to_s)
    end

    # Cash equity is delivery-only. A sell that is not reduce_only may sell only
    # shares the account holds, less the shares its own open sell orders still
    # reserve. Runs inside the order-save transaction, after the account row is
    # locked. Fills take the same lock (Ledger::MarginLedger.lock_margin!), so a
    # concurrent fill is either fully visible here or waits for this check.
    def assert_equity_holdings!(attrs)
      return unless attrs[:instrument_type] == "EQUITY" && attrs[:side] == "sell" && !attrs[:reduce_only]

      Account.lock.find_by!(account_id: account_id)
      held = ::PaperExchange::PaperPosition
        .where(account_id: account_id, symbol: attrs[:symbol], instrument_type: "EQUITY", side: :long)
        .sum(:quantity)
      reserved = ::PaperExchange::PaperOrder
        .where(account_id: account_id, symbol: attrs[:symbol], instrument_type: "EQUITY", side: :sell,
               status: %i[pending open partially_filled])
        .sum { |order| order.quantity - order.filled_quantity }
      available = held - reserved
      return if attrs[:quantity] <= available

      raise InsufficientHoldingError,
        "sell #{attrs[:quantity]} #{attrs[:symbol]} rejected: #{available} held and unreserved; cash equity cannot be sold short"
    end

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
      return if order.locked_margin.zero?

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
