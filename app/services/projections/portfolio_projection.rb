module Projections
  class PortfolioProjection
    class << self
      ZEROS = {
        account_id: nil,
        positions_count: 0,
        unrealized_pnl: 0.0,
        equity: 0.0,
        max_equity: 0.0,
        drawdown: 0.0,
        realized_pnl: 0.0
      }.freeze

      def summary(account_id)
        account = Account.find_by(account_id: account_id)
        return ZEROS unless account

        positions = PositionProjection.for_account(account_id)
        unrealized = positions.sum { |p| p[:unrealized_pnl].to_f }
        equity = account.current_equity.to_f
        max_equity = [equity, account.margin.to_f].max
        drawdown = max_equity > 0 ? ((max_equity - equity) / max_equity) * 100 : 0.0

        realized = LedgerEntry.where(account_id: account_id, event_type: "trade").sum do |entry|
          (entry.payload && entry.payload["realized_pnl"]) ? entry.payload["realized_pnl"].to_f : 0.0
        end

        {
          account_id: account_id,
          positions_count: positions.size,
          unrealized_pnl: unrealized.round(2),
          equity: equity.round(2),
          max_equity: max_equity.round(2),
          drawdown: drawdown.round(2),
          realized_pnl: realized.round(2)
        }
      end

      def rebuild_for_account(account_id)
        Account.find_by(account_id: account_id)&.tap do |account|
          next unless account

          # Reset P&L accumulators to baseline
          unrealized = 0.0
          realized = 0.0
          max_equity = account.current_equity.to_f

          LedgerEntry.where(account_id: account_id, event_type: "trade").order(:occurred_at).find_each do |entry|
            payload = entry.payload || {}
            component = (payload["realized_pnl"] || 0.0).to_f
            component += (payload["unrealized_pnl"] || 0.0).to_f if entry.event_type == "position"
            realized += component if entry.event_type == "trade"
            unrealized += (payload["unrealized_pnl"] || 0.0).to_f if entry.event_type == "position"

            equity = account.margin.to_f + realized + unrealized
            max_equity = equity if equity > max_equity

            account.update_columns(
              realized_pnl: realized.round(2),
              unrealized_pnl: unrealized.round(2),
              current_equity: equity.round(2)
            )
          end
        end
      end
    end
  end
end
