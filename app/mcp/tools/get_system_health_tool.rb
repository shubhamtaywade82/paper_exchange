# frozen_string_literal: true

class GetSystemHealthTool < ApplicationMCPTool
  tool_name "get_system_health"
  description "Fetch backend dependency health (PostgreSQL, Redis, Solid Queue) and venue connectivity"

  def perform
    postgres_ok = begin
      ActiveRecord::Base.connection.active?
    rescue StandardError
      false
    end

    redis_ok = begin
      MarketData::MarkPriceStore.redis_healthy?
    rescue StandardError
      false
    end

    solid_queue_ok = if ActiveJob::Base.queue_adapter_name.to_s == "solid_queue" && defined?(SolidQueue::Job)
      begin
        SolidQueue::Job.connection.active?
      rescue StandardError
        false
      end
    else
      true
    end

    healthy = postgres_ok && redis_ok && solid_queue_ok

    render_json(
      status: healthy ? "ok" : "degraded",
      checks: {
        postgres: postgres_ok,
        redis: redis_ok,
        solid_queue: solid_queue_ok
      },
      environment: Rails.env,
      providers: {
        binance_enabled: ENV["PAPER_EXCHANGE_ENABLE_BINANCE"] == "true",
        coindcx_enabled: ENV["PAPER_EXCHANGE_ENABLE_COINDCX"] == "true"
      }
    )
  end
end
