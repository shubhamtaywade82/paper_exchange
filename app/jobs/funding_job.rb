# Settles perpetual futures funding for every open leveraged position.
# Binance charges/pays funding every 8 hours (00:00 / 16:00 / 08:00 UTC —
# see config/recurring.yml); this job fetches the current funding rate for
# each symbol with an open position and posts one FundingPayment + one
# LedgerEntry per position.
#
# Convention (matches Binance): a positive funding rate means longs pay
# shorts. `amount` on the resulting records is signed from the account's own
# point of view — positive means the account paid, negative means it
# received.
class FundingJob < ApplicationJob
  queue_as :risk

  PREMIUM_INDEX_URL = "https://fapi.binance.com/fapi/v1/premiumIndex".freeze

  def perform(symbol = nil)
    positions = ::PaperExchange::PaperPosition.where("leverage > 1 AND quantity <> 0")
    positions = positions.where(symbol: symbol) if symbol
    return if positions.none?

    rates = fetch_funding_rates(positions.distinct.pluck(:symbol))

    positions.find_each do |position|
      rate_info = rates[position.symbol.to_s.upcase]
      next unless rate_info

      apply_funding!(position, rate_info)
    end
  end

  private

  def fetch_funding_rates(symbols)
    wanted = symbols.map { |s| s.to_s.upcase }
    response = Faraday.get(PREMIUM_INDEX_URL)
    raise "Binance premiumIndex error: #{response.status}" unless response.success?

    JSON.parse(response.body).each_with_object({}) do |entry, memo|
      sym = entry["symbol"]
      next unless wanted.include?(sym)

      memo[sym] = { rate: entry["lastFundingRate"].to_f, mark_price: entry["markPrice"].to_f }
    end
  end

  def apply_funding!(position, rate_info)
    mark_price = rate_info[:mark_price]
    mark_price = MarketData::MarkPriceStore.get(position.symbol) || position.current_price.to_f if mark_price.to_f.zero?

    notional = position.notional_value(mark_price)
    funding_rate = rate_info[:rate]
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

    LedgerEntry.create!(
      account_id: position.account_id,
      event_type: "FUNDING_FEE",
      debit: amount.positive? ? amount : 0,
      credit: amount.negative? ? amount.abs : 0,
      reference_id: position.id.to_s,
      payload: {
        position_id: position.id,
        symbol: position.symbol,
        funding_rate: funding_rate,
        notional: notional
      },
      occurred_at: Time.current
    )

    Ledger::Ledger.refresh_cached_equity!(position.account_id)
  end
end
