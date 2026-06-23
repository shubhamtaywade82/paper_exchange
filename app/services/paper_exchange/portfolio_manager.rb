module PaperExchange
  class PortfolioManager
    def initialize(account_id, market_data_feed:)
      @account_id = account_id
      @market_data_feed = market_data_feed
    end

    def positions
      PaperExchange::PaperPosition.where(account_id: @account_id)
    end

    def total_unrealized_pnl
      positions.sum do |pos|
        ltp = @market_data_feed.ltp(pos.symbol) || pos.avg_price || 0
        PnLEngine.unrealized_pnl(pos, ltp)
      end
    end

    def total_realized_pnl
      positions.sum { |pos| pos.realized_pnl || 0 }
    end

    def summary
      {
        positions_count: positions.count,
        unrealized_pnl: total_unrealized_pnl,
        realized_pnl: total_realized_pnl,
        total_pnl: total_unrealized_pnl + total_realized_pnl
      }
    end
  end
end
