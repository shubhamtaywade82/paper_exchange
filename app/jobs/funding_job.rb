# Settles perpetual futures funding for every open position on one symbol,
# using a funding rate pushed by the trading bot via POST /api/funding_events.
# The bot owns the Binance market-data connection (see README "Crypto market
# data ownership") — this job never calls out to Binance itself, it only
# reacts to what it's told.
#
# Convention (matches Binance): a positive funding rate means longs pay
# shorts. `amount` on the resulting records is signed from the account's own
# point of view — positive means the account paid, negative means it
# received.
#
# P0-2 fix: funding settlement is now ATOMIC with its idempotency record.
# The FundingPayment row and the wallet/ledger movement are created in a
# SINGLE database transaction — if the ledger post raises, the payment row
# rolls back too, so a retried job re-settles from scratch instead of
# silently skipping the wallet movement. Previously the payment was committed
# first and the ledger posted afterward, creating a window where a crash
# left a "settled" payment with no corresponding wallet adjustment.
#
# P0-2 fix: funding eligibility is based on the instrument being a crypto
# perpetual with an open quantity, NOT on leverage > 1. Binance USD-M
# perpetuals incur funding at 1x leverage too — the old filter silently
# skipped 1x positions and understated funding costs.
#
# Idempotency: when `funding_time` is supplied (Binance's settlement
# timestamp), FundingPayment is keyed unique on (paper_position_id,
# funding_time). A retry of the same event hits the existing record and
# skips the ledger post — no double-charge. Both the payment row and the
# ledger entry are inside the same transaction so the dedup is structural.
class FundingJob < ApplicationJob
  queue_as :risk

  # P0-2: a position deleted between enqueue and perform (manual close,
  # account reset, liquidation) is not a retriable failure.
  discard_on ActiveRecord::RecordNotFound

  def perform(symbol, funding_rate, mark_price = nil, funding_time = nil)
    # P0-2: filter on open perpetual positions regardless of leverage.
    # Binance USD-M perpetuals incur funding at 1x too.
    positions = ::PaperExchange::PaperPosition
      .where(symbol: symbol)
      .where("instrument_type = ? AND quantity <> 0", Exchange::CryptoInstrumentCatalog::PERPETUAL)
    return if positions.none?

    positions.find_each { |position| apply_funding!(position, funding_rate.to_f, mark_price, funding_time) }
  end

  private

  def apply_funding!(position, funding_rate, mark_price, funding_time)
    mark_price = mark_price.to_f if mark_price
    mark_price = MarketData::MarkPriceStore.get(position.symbol) || position.current_price.to_f if mark_price.to_f.zero?

    notional = position.notional_value(mark_price)
    direction = position.long? ? 1 : -1
    amount = notional * funding_rate * direction

    # P0-2: atomic payment + ledger movement. Both succeed or both roll back.
    # The find_or_initialize_by dedup still works inside the transaction —
    # if the payment already exists (from a prior committed settlement), the
    # transaction is a no-op.
    ::FundingPayment.transaction do
      dedup_attrs = { paper_position: position, funding_time: funding_time }
      payment = FundingPayment.find_or_initialize_by(dedup_attrs)
      already_existed = payment.persisted?
      payment.assign_attributes(
        account_id: position.account_id,
        symbol: position.symbol,
        funding_rate: funding_rate,
        position_notional: notional,
        amount: amount,
        occurred_at: Time.current
      )
      payment.save! unless already_existed
      return if already_existed

      payload = {
        position_id: position.id,
        symbol: position.symbol,
        funding_rate: funding_rate,
        notional: notional
      }

      if amount.positive?
        Ledger::MarginLedger.deduct_fee!(
          account_id: position.account_id,
          amount: amount,
          event_type: "FUNDING_FEE",
          reference_id: position.id.to_s,
          payload: payload
        )
      elsif amount.negative?
        Ledger::MarginLedger.credit_realized_pnl!(
          account_id: position.account_id,
          amount: amount.abs,
          event_type: "FUNDING_FEE",
          reference_id: position.id.to_s,
          payload: payload
        )
      else
        LedgerEntry.create!(
          account_id: position.account_id,
          event_type: "FUNDING_FEE",
          debit: 0,
          credit: 0,
          reference_id: position.id.to_s,
          payload: payload,
          occurred_at: Time.current
        )
      end
    end

    Ledger::Ledger.refresh_cached_equity!(position.account_id)
  end
end
