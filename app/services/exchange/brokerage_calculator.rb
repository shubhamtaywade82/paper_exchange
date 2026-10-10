module Exchange
  # Indian market transaction charge calculator.
  #
  # P1-3 fix: STT rates updated to the NSE schedule effective April 1, 2026:
  #   - Options sale (sell side): 0.15% of premium  (was 0.05% — 3x understated)
  #   - Futures sale (sell side): 0.05% of traded value (was 0.01% — 5x understated)
  # These are env-overridable so operators can pin to a specific FY schedule,
  # but the defaults now match the live NSE rates rather than a stale schedule
  # that systematically overstated net profitability.
  class BrokerageCalculator
    def initialize
      @brokerage_floor = ENV.fetch("PAPER_EXCHANGE_BROKERAGE_FLOOR", "20.0").to_f
      @stt_delivery = ENV.fetch("PAPER_EXCHANGE_STT_DELIVERY", "0.025").to_f / 100
      @stt_intraday = ENV.fetch("PAPER_EXCHANGE_STT_INTRADAY", "0.0125").to_f / 100
      # P1-3: NSE FY2026-27 schedule — options sell-side STT is 0.15%,
      # futures sell-side STT is 0.05%.
      @stt_options_sell = ENV.fetch("PAPER_EXCHANGE_STT_OPTIONS_SELL", "0.15").to_f / 100
      @stt_futures_sell = ENV.fetch("PAPER_EXCHANGE_STT_FUTURES_SELL", "0.05").to_f / 100
      @gst_rate = ENV.fetch("PAPER_EXCHANGE_GST", "18").to_f / 100
      @sebi_fee = ENV.fetch("PAPER_EXCHANGE_SEBI_FEE", "0.0001").to_f
      @stamp_duty = ENV.fetch("PAPER_EXCHANGE_STAMP_DUTY", "0.003").to_f / 100
      @exchange_txn = ENV.fetch("PAPER_EXCHANGE_EXCHANGE_TXN", "0.00145").to_f / 100
    end

    def calculate(trade_price:, quantity:, side:, symbol:, instrument_type: "EQUITY")
      segment_class = segment_class_for(instrument_type)
      turnover = trade_price * quantity

      if instrument_type == "CRYPTO_PERPETUAL" || segment_class == "crypto_perpetual"
        fee = (turnover * 0.0004).round(8)
        return {
          brokerage: fee,
          stt: 0.0,
          gst: 0.0,
          sebi: 0.0,
          stamp_duty: 0.0,
          exchange_txn: 0.0,
          total: fee,
          notional: turnover.round(8)
        }
      end

      stt = if segment_class == "equity"
        side == "buy" ? turnover * @stt_delivery : turnover * @stt_intraday
      elsif side == "sell"
        # P1-3: use the updated NSE schedule rates.
        futures_or_options_stt(turnover, instrument_type)
      else
        0.0
      end

      brokerage = [ turnover * 0.0003, @brokerage_floor ].max
      sebi = turnover * @sebi_fee
      stamp = turnover * @stamp_duty if side == "buy"
      exchange = turnover * @exchange_txn
      gst = gst_on(brokerage + sebi + exchange)
      total = brokerage + stt + gst + sebi + (stamp || 0.0) + exchange

      {
        brokerage: brokerage.round(2),
        stt: stt.round(2),
        gst: gst.round(2),
        sebi: sebi.round(2),
        stamp_duty: (stamp || 0.0).round(2),
        exchange_txn: exchange.round(2),
        total: total.round(2),
        notional: turnover.round(2)
      }
    end

    def margin_required_for(trade_price:, quantity:, side:, symbol:, instrument_type: "EQUITY")
      fees = calculate(trade_price: trade_price, quantity: quantity, side: side, symbol: symbol, instrument_type: instrument_type)
      fees[:notional] + fees[:total]
    end

    private

    def segment_class_for(instrument_type)
      case instrument_type
      when "EQUITY" then "equity"
      when "FUTIDX", "FUTSTK", "FUTCUR", "FUTCOM", "OPTFUT" then "future"
      when "OPTIDX", "OPTSTK", "OPTCUR" then "option"
      when "CRYPTO_PERPETUAL" then "crypto_perpetual"
      else "other"
      end
    end

    # P1-3: NSE FY2026-27 STT schedule for derivatives sell-side.
    # Options: 0.15% of premium. Futures: 0.05% of traded value.
    # (Previously: options 0.05%, futures 0.01% — 3x and 5x understated.)
    def futures_or_options_stt(turnover, instrument_type)
      case instrument_type
      when "OPTIDX", "OPTSTK", "OPTCUR"
        turnover * @stt_options_sell
      else
        turnover * @stt_futures_sell
      end
    end

    def gst_on(amount)
      amount * @gst_rate
    end
  end
end
