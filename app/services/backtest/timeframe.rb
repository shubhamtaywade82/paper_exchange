module Backtest
  # Bar resolutions the engine understands, and the annualisation factor used
  # for Sharpe and Sortino.
  module Timeframe
    MINUTES = {
      "1m" => 1, "3m" => 3, "5m" => 5, "15m" => 15, "30m" => 30,
      "1h" => 60, "4h" => 240, "1d" => 1440
    }.freeze
    SUPPORTED = MINUTES.keys.freeze

    # NSE cash session 09:15-15:30 IST. Crypto trades around the clock.
    NSE_SESSION_MINUTES = 375
    CRYPTO_SESSION_MINUTES = 1440
    NSE_TRADING_DAYS = 252
    CRYPTO_TRADING_DAYS = 365

    module_function

    def seconds(timeframe)
      MINUTES.fetch(timeframe) * 60
    end

    # Number of bars in a year for the instrument's market calendar. Daily
    # bars count trading days; intraday bars count sessions x bars per session.
    def periods_per_year(timeframe, instrument_type)
      crypto = instrument_type.to_s.start_with?("CRYPTO_")
      days = crypto ? CRYPTO_TRADING_DAYS : NSE_TRADING_DAYS
      return days if timeframe == "1d"

      session = crypto ? CRYPTO_SESSION_MINUTES : NSE_SESSION_MINUTES
      days * (session / MINUTES.fetch(timeframe))
    end
  end
end
