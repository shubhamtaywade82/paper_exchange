# Settles perpetual futures funding for every open leveraged position on one
# symbol, using a funding rate pushed by the trading bot via
# POST /api/funding_events. The bot owns the Binance market-data connection
# (see README "Crypto market data ownership") — this job never calls out to
# Binance itself, it only reacts to what it's told.
#
# Convention (matches Binance): a positive funding rate means longs pay
# shorts. `amount` on the resulting records is signed from the account's own
# point of view — positive means the account paid, negative means it
# received.
class FundingJob < ApplicationJob
  queue_as :risk

  def perform(symbol, funding_rate, mark_price = nil)
    positions = ::PaperExchange::PaperPosition
      .where(symbol: symbol)
      .where("leverage > 1 AND quantity <> 0")
    return if positions.none?

    positions.find_each { |position| apply_funding!(position, funding_rate.to_f, mark_price) }
  end

  private

  def apply_funding!(position, funding_rate, mark_price)
    mark_price = mark_price.to_f if mark_price
    mark_price = MarketData::MarkPriceStore.get(position.symbol) || position.current_price.to_f if mark_price.to_f.zero?

    notional = position.notional_value(mark_price)
    direction = position.long? ? 1 : -1
    amount = notional * funding_rate * direction

    FundingPayment.create!(
      account_id: position.account_id,
      paper_position: position,
      symbol: position.symbol,
      funding_rate: funding_rate,
      position_notional: notional,
      amount: amount,
      occurred_at: Time.current
    )

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

    Ledger::Ledger.refresh_cached_equity!(position.account_id)
  end
end
