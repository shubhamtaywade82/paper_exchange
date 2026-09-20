module Exchange
  # Applies one fill to an account's position for a specific contract.
  #
  # A "contract" is (account_id, symbol, instrument_type, option_type,
  # strike_price, expiry_date) — exactly the columns backing
  # `index_paper_positions_uniqueness`. `side` is a mutable attribute of that
  # one row, not part of its identity: a position can go long, flatten, and
  # go short again without ever changing which row represents it. Looking
  # positions up by symbol+side alone (the previous implementation) collapsed
  # distinct contracts on the same underlying — e.g. a NIFTY OPTIDX 26000 CE
  # and a NIFTY OPTIDX 26000 PE both read as "symbol=NIFTY", so opening the
  # second would silently corrupt the first's quantity/avg_price.
  #
  # `quantity` is always stored as a non-negative magnitude; `side` alone
  # carries direction. (The previous implementation encoded direction a
  # second time via the sign of the fill quantity passed in, which
  # contradicted `side` for the very first fill of a short position:
  # `[total_qty, 0].max` with a negative `total_qty` always produced a
  # zero-quantity row — opening a short from flat was silently a no-op.)
  class PositionManager
    def self.apply!(account_id:, symbol:, side:, quantity:, avg_price:, leverage: 1, margin_type: "cross", instrument_type: "EQUITY", option_type: nil, strike_price: nil, expiry_date: nil)
      fill_side = normalize_side(side)
      fill_qty = to_decimal(quantity).abs
      return if fill_qty.zero?

      fill_price = to_decimal(avg_price)
      contract_scope = {
        account_id: account_id,
        symbol: symbol,
        instrument_type: instrument_type,
        option_type: option_type,
        strike_price: strike_price,
        expiry_date: expiry_date
      }

      position = ::PaperExchange::PaperPosition.find_by(contract_scope) ||
        ::PaperExchange::PaperPosition.new(contract_scope.merge(side: fill_side, quantity: 0, avg_price: 0))

      current_qty = to_decimal(position.quantity)
      was_flat = current_qty.zero?

      if was_flat || position.side == fill_side
        # Opening from flat, or adding to the position in the same
        # direction: weighted-average the entry price.
        position.side = fill_side if was_flat
        new_qty = current_qty + fill_qty
        position.avg_price = ((to_decimal(position.avg_price) * current_qty) + (fill_price * fill_qty)) / new_qty
        position.quantity = new_qty
        if was_flat
          position.leverage = leverage
          position.margin_type = margin_type
        end
      else
        # Opposite direction: reduce, fully close, or flip through zero —
        # all handled in place on the same row, so trades recorded against
        # this position's id stay valid across its whole lifecycle (destroy
        # + recreate would violate the FK from paper_exchange_trades the
        # moment any trade had already been recorded against it).
        case fill_qty <=> current_qty
        when -1
          position.quantity = current_qty - fill_qty
        when 0
          position.quantity = 0
          position.avg_price = 0
        when 1
          position.side = fill_side
          position.quantity = fill_qty - current_qty
          position.avg_price = fill_price
          position.leverage = leverage
          position.margin_type = margin_type
        end
      end

      position.current_price = fill_price
      position.save!
      position
    end

    def self.normalize_side(side)
      case side.to_s.downcase
      when /buy/ then 'long'
      when /sell/ then 'short'
      else side.to_s
      end
    end

    def self.to_decimal(value)
      BigDecimal(value.to_s)
    end
    private_class_method :to_decimal
  end
end
