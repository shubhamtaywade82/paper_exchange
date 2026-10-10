module Api
  # Architecture alignment (target architecture §6): exchange status endpoint.
  # Reports provider connectivity, quote freshness, and degraded state so
  # the trading bot (and operators) can detect when the exchange's own
  # market-data feeds are down — before stale quotes cause bad fills.
  class ExchangeController < BaseController
    def status
      providers = collect_provider_health
      quotes = collect_quote_freshness

      all_connected = providers.values.all? { |h| h[:connected] }
      any_stale = quotes.values.any? { |q| q[:stale] }

      status_code = (all_connected && !any_stale) ? :ok : :service_unavailable

      render json: {
        status: (all_connected && !any_stale) ? "ok" : "degraded",
        providers: providers,
        quotes: quotes,
        matching_worker: matching_worker_status
      }, status: status_code
    end

    private

    def collect_provider_health
      result = {}
      active_providers.each do |provider|
        result[provider.venue] = provider.health
      end
      result
    end

    def collect_quote_freshness
      quotes = {}
      ::PaperExchange::PaperPosition
        .where("quantity <> 0")
        .distinct
        .pluck(:venue, :symbol)
        .each do |venue, symbol|
          quote = MarketData::QuoteStore.get(venue, symbol)
          quotes["#{venue}:#{symbol}"] = {
            venue: venue,
            instrument_id: symbol,
            stale: quote.nil? || MarketData::QuoteStore.stale?(quote),
            received_at: quote&.dig(:received_at),
            mark_price: quote&.dig(:mark_price)
          }
        end
      quotes
    end

    def matching_worker_status
      # The matching worker is a recurring Solid Queue job — its liveness
      # is inferred from the last time it ran. A full implementation would
      # check SolidQueue::Job for the last successful run.
      { running: defined?(Exchange::MatchingWorker) }
    end

    # Returns the list of active provider instances. In production these
    # are managed by the ConnectionSupervisor; in test/dev they're empty
    # (the agent pushes prices directly via POST /api/mark_prices).
    def active_providers
      @active_providers ||= begin
        providers = []
        providers << MarketData::Providers::BinanceUsdm.new if ENV["PAPER_EXCHANGE_ENABLE_BINANCE"] == "true"
        providers << MarketData::Providers::CoindcxFutures.new if ENV["PAPER_EXCHANGE_ENABLE_COINDCX"] == "true"
        providers
      end
    end
  end
end
