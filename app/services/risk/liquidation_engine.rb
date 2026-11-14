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
  #
  # A breached position stays in the watch cache until the database shows it
  # closed (refresh_cache! prunes it). Re-enqueueing is throttled by `pending`:
  # each enqueue records when it expires, so a burst of ticks enqueues once.
  # If LiquidationJob fails or does not close the position, the entry expires
  # and the next breaching price enqueues it again. The previous version
  # removed the position from the cache on enqueue, so a failed job left it
  # unwatched until some later refresh (#9).
  class LiquidationEngine
    # Seconds before a breached, still-open position is enqueued again.
    PENDING_TTL = 5.0

    class << self
      # Test seam: a callable returning monotonic seconds.
      attr_writer :clock

      def refresh_cache!
        rows = ::PaperExchange::PaperPosition
          .live_accounts
          .where("leverage > 1 AND quantity <> 0 AND liquidation_price IS NOT NULL")
          .pluck(:id, :symbol, :side, :liquidation_price)

        mutex.synchronize do
          cache.replace(rows.group_by { |(_id, symbol, *)| symbol.to_s.upcase })
          open_ids = rows.map(&:first).to_set
          pending.delete_if { |id, _expires_at| !open_ids.include?(id) }
        end
      end

      def check_symbol!(symbol, mark_price)
        key = symbol.to_s.upcase
        price = mark_price.to_f

        mutex.synchronize do
          positions = cache[key]
          next if positions.blank?

          now = clock.call
          positions.each do |(id, _symbol, side, liquidation_price)|
            is_long = side.to_s == "long" || side.to_s == "0"
            breached = is_long ? price <= liquidation_price.to_f : price >= liquidation_price.to_f
            next unless breached
            next if pending.key?(id) && pending[id] > now

            pending[id] = now + PENDING_TTL
            LiquidationJob.perform_later(id, price)
          end
        end
      end

      def reset_cache!
        mutex.synchronize do
          cache.clear
          pending.clear
        end
      end

      private

      def mutex
        @mutex ||= Mutex.new
      end

      def cache
        @cache ||= Concurrent::Hash.new
      end

      def pending
        @pending ||= {}
      end

      def clock
        @clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      end
    end
  end
end
