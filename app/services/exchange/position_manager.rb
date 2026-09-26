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
  #
  # Concurrency (audit M4): every apply takes a SELECT ... FOR UPDATE row
  # lock on the contract's position, so two concurrent fills of the same
  # contract can never read-modify-write past each other. The normal
  # submit_order path already serializes same-account orders on the account
  # row, but reduce-only/liquidation closes skip that lock — an opening
  # order racing a liquidation close hit exactly this window. For the
  # first fill from flat there is no row to lock, so the partial unique
  # index `index_paper_positions_contract_strict` (added for exactly the
  # NULL-dimension contracts the old composite index could not protect)
  # arbitrates the race: the loser gets ActiveRecord::RecordNotUnique,
  # rolls back to the savepoint, re-locks the winner's now-committed row,
  # and re-applies its fill on top. The savepoint is what makes the
  # violation recoverable inside the caller's fill transaction.
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

      attempts = 0
      begin
        apply_locked!(contract_scope, fill_side, fill_qty, fill_price, leverage, margin_type)
      rescue ActiveRecord::RecordNotUnique
        attempts += 1
        raise if attempts > 1

        retry
      end
    end

    # Returns the LOCKED, mutated position instance. Callers that need to
    # act on the position right after the fill (MarginEngine.sync_position!)
    # must use this instance — its in-memory attributes reflect the fill
    # that was just applied under the lock (audit S6).
    def self.apply_locked!(contract_scope, fill_side, fill_qty, fill_price, leverage, margin_type)
      ::PaperExchange::PaperPosition.transaction(requires_new: true) do
        position = ::PaperExchange::PaperPosition.lock.where(contract_scope).first
        position ||= ::PaperExchange::PaperPosition.new(contract_scope.merge(side: fill_side, quantity: 0, avg_price: 0))

        current_qty = to_decimal(position.quantity)
        was_flat = current_qty.zero?
        realized_pnl = BigDecimal("0")

        if was_flat || position.side == fill_side
          # Opening from flat, or adding to the position in the same direction.
          position.side = fill_side if was_flat
          new_qty = current_qty + fill_qty
          position.avg_price = ((to_decimal(position.avg_price) * current_qty) + (fill_price * fill_qty)) / new_qty
          position.quantity = new_qty
          if was_flat
            position.leverage = leverage
            position.margin_type = margin_type
          end
        else
          closed_qty = [ fill_qty, current_qty ].min
          old_entry_price = to_decimal(position.avg_price)
          pnl_multiplier = position.side == "long" ? 1 : -1
          realized_pnl = (fill_price - old_entry_price) * closed_qty * pnl_multiplier

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
        position.last_realized_pnl = realized_pnl
        position.save!
        position
      end
    end

    def self.normalize_side(side)
      case side.to_s.downcase
      when /buy/ then "long"
      when /sell/ then "short"
      else side.to_s
      end
    end

    def self.to_decimal(value)
      BigDecimal(value.to_s)
    end
    private_class_method :to_decimal
  end
end
