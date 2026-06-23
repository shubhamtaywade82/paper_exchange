module PaperExchange
  class BrokerageCalculator
    BROKERAGE_LIMIT = 20.0
    BROKERAGE_RATE  = 0.0003

    STT_DELIVERY     = 0.001     # 0.10%
    STT_INTRADAY     = 0.00025   # 0.025%
    EXCHANGE_TXN_RATE = 0.0000345
    GST_RATE         = 0.18
    SEBI_RATE        = 0.000001
    STAMP_DUTY_RATE  = 0.00015   # buy-side only

    def calculate(trade)
      turnover = trade.price * trade.quantity

      brokerage      = [BROKERAGE_LIMIT, turnover * BROKERAGE_RATE].min
      stt            = stt_charge(trade.side, turnover)
      exchange_txn   = turnover * EXCHANGE_TXN_RATE
      gst            = (brokerage + exchange_txn) * GST_RATE
      sebi           = turnover * SEBI_RATE
      stamp_duty     = trade.side == "buy" ? turnover * STAMP_DUTY_RATE : 0
      total          = brokerage + stt + exchange_txn + gst + sebi + stamp_duty

      {
        brokerage: brokerage,
        stt: stt,
        exchange_txn: exchange_txn,
        gst: gst,
        sebi: sebi,
        stamp_duty: stamp_duty,
        total: total
      }
    end

    private

    def stt_charge(side, turnover)
      side == "sell" ? turnover * STT_DELIVERY : turnover * STT_INTRADAY
    end
  end
end
