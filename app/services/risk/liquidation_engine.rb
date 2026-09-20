module Risk
  # In-memory cache of open leveraged positions, checked against every
  # mark price the trading agent pushes via POST /api/mark_prices (this
  # broker has no market-data connection of its own — see README "Crypto
  # market data ownership"). `refresh_cache!` is called on every push (see
  # Api::MarkPricesController) to pick up new/closed positions;
  # `check_symbol!` is the per-price check.
  #
  # When a position's liquidation price is breached this only enqueues
  # LiquidationJob — the actual force-close (a DB write, an exchange fill) is
  # never performed inline on the request thread.
  class LiquidationEngine
    class << self
      def refresh_cache!
        rows = ::PaperExchange::PaperPosition
          .where("leverage > 1 AND quantity <> 0 AND liquidation_price IS NOT NULL")
          .pluck(:id, :symbol, :side, :liquidation_price)

        cache.replace(rows.group_by { |(_id, symbol, *)| symbol.to_s.upcase })
      end

      def check_symbol!(symbol, mark_price)
        key = symbol.to_s.upcase
        positions = cache[key]
        return if positions.blank?

        price = mark_price.to_f
        breached_ids = []

        positions.each do |(id, _symbol, side, liquidation_price)|
          # `pluck` on an enum column returns its string label ("long"/
          # "short"), not the underlying integer — comparing via `.to_i`
          # here would silently treat every row as "long" (`.to_i` is 0 for
          # both labels).
          breached = side == "long" ? price <= liquidation_price.to_f : price >= liquidation_price.to_f
          next unless breached

          LiquidationJob.perform_later(id, price)
          breached_ids << id
        end

        # Drop breached positions immediately so a burst of ticks arriving
        # before the job runs doesn't enqueue the same liquidation repeatedly.
        cache[key] = positions.reject { |p| breached_ids.include?(p[0]) } if breached_ids.any?
      end

      def reset_cache!
        cache.clear
      end

      private

      def cache
        @cache ||= Concurrent::Hash.new
      end
    end
  end
end
