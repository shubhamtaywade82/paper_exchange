# Architecture alignment (target architecture §6): option expiry settlement.
# Storing `expiry_date` on a position does not itself settle or close it —
# this job scans for positions whose expiry_date has passed and settles them.
#
# Settlement model (simplified for paper trading):
#   - ITM options (in-the-money) are exercised at the intrinsic value:
#       Call: max(underlying_price - strike, 0)
#       Put:  max(strike - underlying_price, 0)
#   - OTM/ATM options expire worthless — the position is closed at zero.
#   - The realized PnL is posted through the normal ledger path.
#
# For Indian F&O, physical settlement of index options is not standard —
# they are cash-settled. This job implements cash settlement: the position
# is closed at the settlement price (the mark price at expiry), and the
# realized PnL is the difference between the entry price and the settlement
# price (for the option premium, not the underlying).
#
# Run daily (e.g. at market close) via config/recurring.yml.
class OptionExpiryJob < ApplicationJob
  queue_as :default

  def perform
    ::PaperExchange::PaperPosition
      .where.not(option_type: nil)
      .where.not(quantity: 0)
      .where("expiry_date < ?", Date.today)
      .find_each { |position| settle!(position) }
  end

  private

  def settle!(position)
    return unless position.option_type.present? && position.expiry_date

    underlying_price = fetch_underlying_price(position)
    settlement_price = settlement_value(position, underlying_price)

    exchange = Exchange::PaperExchange.new(account_id: position.account_id)
    close_side = position.long? ? "sell" : "buy"

    # Close the position at the settlement price. internal:true bypasses
    # the margin lock (the position is being force-settled, not traded).
    # reduce_only:true ensures we never open an opposite position.
    exchange.submit_order(
      account_id: position.account_id,
      symbol: position.symbol,
      side: close_side,
      quantity: position.quantity.to_f,
      order_kind: "market",
      instrument_type: position.instrument_type,
      option_type: position.option_type,
      strike_price: position.strike_price,
      expiry_date: position.expiry_date,
      ltp: settlement_price,
      leverage: position.leverage,
      margin_type: position.margin_type,
      context: { reason: "OPTION_EXPIRY", underlying_price: underlying_price.to_s },
      internal: true,
      reduce_only: true,
      client_order_id: "expiry-#{position.id}"
    )

    RiskEvent.create!(
      account_id: position.account_id,
      event_type: "OPTION_EXPIRED",
      details: {
        position_id: position.id,
        symbol: position.symbol,
        option_type: position.option_type,
        strike_price: position.strike_price.to_s,
        expiry_date: position.expiry_date.to_s,
        underlying_price: underlying_price.to_s,
        settlement_price: settlement_price.to_s
      }
    )
  rescue Exchange::PaperExchange::PositionGoneError
    # Already closed — nothing to settle.
    nil
  rescue ::PaperExchange::PaperOrder::StateError
    # Settlement order already exists (idempotent client_order_id).
    nil
  end

  def fetch_underlying_price(position)
    MarketData::MarkPriceStore.get(position.symbol) ||
      MarketData::MarkPriceStore.get(underlying_symbol(position.symbol)) ||
      position.current_price.to_f
  end

  # For index options, the "underlying" is the index itself (NIFTY, BANKNIFTY).
  # The symbol on the position is the option contract symbol, but the
  # underlying price comes from the index. This is a simplification — a full
  # implementation would resolve the option contract to its underlying via
  # the instrument catalog.
  def underlying_symbol(option_symbol)
    # Strip common option suffix patterns (e.g. NIFTY26000CE270624 → NIFTY)
    option_symbol.to_s.gsub(/\d+.*\z/, "")
  end

  # Cash settlement value: for an option that expires, the settlement is
  # the intrinsic value (ITM) or zero (OTM). The position's avg_price is
  # the premium paid/received — the realized PnL is the difference between
  # the settlement value and the entry premium.
  def settlement_value(position, underlying_price)
    return 0.0 if underlying_price.nil? || underlying_price <= 0

    strike = position.strike_price.to_f
    case position.option_type
    when "CE" # Call: ITM when underlying > strike
      [ underlying_price - strike, 0.0 ].max
    when "PE" # Put: ITM when underlying < strike
      [ strike - underlying_price, 0.0 ].max
    else
      0.0
    end
  end
end
