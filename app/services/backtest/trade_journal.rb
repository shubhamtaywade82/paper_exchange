module Backtest
  # Turns a run's fills into closed round-trip trades.
  #
  # Fills are replayed in the order they were booked, with the same
  # average-cost arithmetic as Exchange::PositionManager. A trip is one
  # flat-to-flat cycle:
  #   * an add updates the average entry price
  #   * a reduce books realized P&L on the closed quantity
  #   * a flip closes the trip and opens the next one with the remainder
  # Commissions are each fill's total_charges. When a fill straddles a close,
  # its charges are split pro rata.
  #
  # Invariant (covered by specs): the trips' gross P&L sums to the account's
  # REALIZED_PNL ledger entries, and their commissions sum to its FEE entries.
  class TradeJournal
    def self.build(account_id:, exit_reasons:)
      new(account_id, exit_reasons).build
    end

    def initialize(account_id, exit_reasons)
      @account_id = account_id
      @exit_reasons = exit_reasons
      @qty = zero
      @avg = zero
      @trip = nil
      @closed = []
    end

    def build
      fills.each { |fill| apply(fill) }
      @closed
    end

    private

    def zero
      BigDecimal("0")
    end

    def fills
      ::PaperExchange::PaperTrade
        .joins(:paper_order)
        .preload(:paper_order)
        .where(paper_exchange_orders: { account_id: @account_id })
        .order(traded_at: :asc, id: :asc)
    end

    def apply(fill)
      qty = fill.quantity
      delta = fill.side == "buy" ? qty : -qty

      if @qty.zero?
        open_trip(delta, fill.price, qty, fill.total_charges, fill)
      elsif @qty.positive? == delta.positive?
        add_to_trip(delta, fill.price, qty, fill.total_charges)
      else
        reduce_or_flip(delta, fill.price, qty, fill.total_charges, fill)
      end
    end

    def open_trip(signed_qty, price, qty, charges, fill)
      order = fill.paper_order
      @qty = signed_qty
      @avg = price
      @trip = {
        symbol: order.symbol,
        instrument_type: order.instrument_type,
        option_type: order.option_type,
        strike_price: order.strike_price,
        expiry_date: order.expiry_date,
        direction: signed_qty.positive? ? "long" : "short",
        entry_at: fill.traded_at,
        entry_order_id: order.id,
        entry_qty: zero,
        entry_notional: zero,
        entry_charges: zero,
        exit_qty: zero,
        exit_notional: zero,
        exit_charges: zero,
        gross: zero,
        exit_at: nil,
        exit_order_id: nil
      }
      record_entry(qty, price, charges)
    end

    def add_to_trip(delta, price, qty, charges)
      new_qty = @qty + delta
      @avg = ((@avg * @qty.abs) + (price * qty)) / new_qty.abs
      @qty = new_qty
      record_entry(qty, price, charges)
    end

    def reduce_or_flip(delta, price, qty, charges, fill)
      direction = @qty.positive? ? 1 : -1
      closed_qty = [ @qty.abs, qty ].min
      close_charges = charges * closed_qty / qty

      @trip[:gross] += (price - @avg) * closed_qty * direction
      @trip[:exit_qty] += closed_qty
      @trip[:exit_notional] += price * closed_qty
      @trip[:exit_charges] += close_charges
      @trip[:exit_at] = fill.traded_at
      @trip[:exit_order_id] = fill.paper_order.id

      new_qty = @qty + delta
      if new_qty.zero?
        close_trip
      elsif new_qty.positive? == @qty.positive?
        @qty = new_qty
      else
        close_trip
        open_trip(new_qty, price, qty - closed_qty, charges - close_charges, fill)
      end
    end

    def record_entry(qty, price, charges)
      @trip[:entry_qty] += qty
      @trip[:entry_notional] += price * qty
      @trip[:entry_charges] += charges
    end

    def close_trip
      trip = @trip
      @trip = nil
      @qty = zero
      @avg = zero

      commission = trip[:entry_charges] + trip[:exit_charges]
      notional = trip[:entry_notional]
      net = trip[:gross] - commission
      @closed << {
        symbol: trip[:symbol],
        instrument_type: trip[:instrument_type],
        option_type: trip[:option_type],
        strike_price: trip[:strike_price],
        expiry_date: trip[:expiry_date],
        direction: trip[:direction],
        quantity: trip[:entry_qty],
        entry_at: trip[:entry_at],
        entry_price: trip[:entry_notional] / trip[:entry_qty],
        entry_order_id: trip[:entry_order_id],
        exit_at: trip[:exit_at],
        exit_price: trip[:exit_notional] / trip[:exit_qty],
        exit_order_id: trip[:exit_order_id],
        exit_reason: @exit_reasons.fetch(trip[:exit_order_id], "unmapped"),
        gross_pnl: trip[:gross],
        commission: commission,
        net_pnl: net,
        notional: notional,
        return_pct: net / notional * 100
      }
    end
  end
end
