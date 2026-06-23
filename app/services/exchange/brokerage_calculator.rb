module Exchange
  class BrokerageCalculator
    def initialize
      @brokerage_floor = ENV.fetch("PAPER_EXCHANGE_BROKERAGE_FLOOR", "20.0").to_f
      @stt_delivery = ENV.fetch("PAPER_EXCHANGE_STT_DELIVERY", "0.025").to_f / 100
      @stt_intraday = ENV.fetch("PAPER_EXCHANGE_STT_INTRADAY", "0.0125").to_f / 100
      @gst_rate = ENV.fetch("PAPER_EXCHANGE_GST", "18").to_f / 100
      @sebi_fee = ENV.fetch("PAPER_EXCHANGE_SEBI_FEE", "0.0001").to_f
      @stamp_duty = ENV.fetch("PAPER_EXCHANGE_STAMP_DUTY", "0.003").to_f / 100
      @exchange_txn = ENV.fetch("PAPER_EXCHANGE_EXCHANGE_TXN", "0.00145").to_f / 100
    end

    def for(trade_price:, quantity:, side:, symbol:, instrument_type: "equity")
      turnover = trade_price * quantity
      stt = if instrument_type == "equity" && side == "buy"
        turnover * @stt_delivery
      elsif instrument_type == "equity"
        turnover * @stt_intraday
      else
        0.0
      end

      brokerage = [turnover * 0.0003, @brokerage_floor].max
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
        total: total.round(2)
      }
    end

    private

    def gst_on(amount)
      amount * @gst_rate
    end
  end
end
