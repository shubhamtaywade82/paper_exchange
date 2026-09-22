module Ledger
  class InsufficientMarginError < StandardError; end

  # Atomic margin wallet operations. Moves funds between an account's
  # `available_balance` and `locked_margin` under `SELECT ... FOR UPDATE`, so
  # concurrent order submissions on the same account can never both observe
  # (and spend) the same available balance. Every movement is also recorded
  # as an immutable LedgerEntry.
  class MarginLedger
    class << self
      def lock_margin!(account_id:, amount:, reference_id: nil, payload: {})
        amount = to_decimal(amount)
        return nil if amount.zero?
        raise ArgumentError, "amount must be >= 0, got #{amount}" if amount.negative?

        Account.transaction do
          account = Account.lock.find_by!(account_id: account_id)

          if account.available_balance < amount
            raise InsufficientMarginError,
              "account #{account_id} has #{account.available_balance} available, needs #{amount}"
          end

          account.update!(
            available_balance: account.available_balance - amount,
            locked_margin: account.locked_margin + amount
          )

          LedgerEntry.create!(
            account_id: account_id,
            event_type: "MARGIN_LOCKED",
            debit: amount,
            credit: 0,
            balance_after: account.available_balance,
            reference_id: reference_id,
            payload: payload,
            occurred_at: Time.current
          )
        end
      end

      # Reverses a lock. The unlocked amount is capped at whatever is
      # currently locked so a double-unlock (e.g. an order cancel racing a
      # fill) can never push `locked_margin` negative.
      def unlock_margin!(account_id:, amount:, reference_id: nil, payload: {})
        amount = to_decimal(amount)
        return nil if amount.zero?
        raise ArgumentError, "amount must be >= 0, got #{amount}" if amount.negative?

        Account.transaction do
          account = Account.lock.find_by!(account_id: account_id)
          released = [amount, account.locked_margin].min

          account.update!(
            available_balance: account.available_balance + released,
            locked_margin: account.locked_margin - released
          )

          LedgerEntry.create!(
            account_id: account_id,
            event_type: "MARGIN_UNLOCKED",
            debit: 0,
            credit: released,
            balance_after: account.available_balance,
            reference_id: reference_id,
            payload: payload,
            occurred_at: Time.current
          )
        end
      end

      def deduct_fee!(account_id:, amount:, event_type: "FEE", reference_id: nil, payload: {})
        amount = to_decimal(amount)
        return nil if amount.zero?
        raise ArgumentError, "amount must be >= 0, got #{amount}" if amount.negative?

        Account.transaction do
          account = Account.lock.find_by!(account_id: account_id)
          account.update!(available_balance: account.available_balance - amount)

          LedgerEntry.create!(
            account_id: account_id,
            event_type: event_type,
            debit: amount,
            credit: 0,
            balance_after: account.available_balance,
            reference_id: reference_id,
            payload: payload,
            occurred_at: Time.current
          )
        end
      end

      def credit_realized_pnl!(account_id:, amount:, event_type: "REALIZED_PNL", reference_id: nil, payload: {})
        amount = to_decimal(amount)
        return nil if amount.zero?

        Account.transaction do
          account = Account.lock.find_by!(account_id: account_id)
          account.update!(available_balance: account.available_balance + amount)

          LedgerEntry.create!(
            account_id: account_id,
            event_type: event_type,
            debit: amount.negative? ? amount.abs : 0,
            credit: amount.positive? ? amount : 0,
            balance_after: account.available_balance,
            reference_id: reference_id,
            payload: payload,
            occurred_at: Time.current
          )
        end
      end

      private

      def to_decimal(amount)
        BigDecimal(amount.to_s)
      end
    end
  end
end
