# frozen_string_literal: true

class GetExchangeConfigTool < ApplicationMCPTool
  tool_name "get_exchange_config"
  description "Exchange risk limits, maximum position notional, drawdown thresholds, VIX gate, and fee schedule. Read-only."

  def perform
    render_json(
      environment: Rails.env,
      risk_limits: {
        max_position_value: ENV.fetch("MAX_POSITION_VALUE", "1000000"),
        max_drawdown_limit: ENV.fetch("MAX_DRAWDOWN", "0.20"),
        max_vix_threshold: ENV.fetch("MAX_VIX", "20.0")
      },
      trading_rules: {
        supported_instruments: %w[EQUITY FUTIDX FUTSTK OPTIDX OPTSTK CRYPTO_PERPETUAL CRYPTO_OPTION],
        margin_types: %w[cross isolated],
        max_leverage: {
          crypto_perpetual: 50,
          equity: 1,
          crypto_option: 1
        }
      },
      server_time: Time.current.iso8601
    )
  end
end
