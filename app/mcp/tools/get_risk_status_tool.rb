# frozen_string_literal: true

class GetRiskStatusTool < ApplicationMCPTool
  tool_name "get_risk_status"
  description "Fetch pre-trade and runtime risk status including drawdown, position limits, and lease status"

  property :account_id, type: "string", description: "Account identifier to inspect (default: test-account-1)"

  def perform
    acc_id = account_id.presence || "test-account-1"
    account = Account.find_by(account_id: acc_id)
    return render_json(error: "account_not_found", account_id: acc_id) unless account

    summary = Projections::PortfolioProjection.summary(acc_id)
    max_positions = (ENV["PAPER_EXCHANGE_MAX_POSITIONS"] || 10).to_i
    max_drawdown = (ENV["PAPER_EXCHANGE_MAX_DRAWDOWN"] || 0.20).to_f
    current_dd_ratio = summary[:drawdown] / 100.0

    lease = AccountLease.find_by(venue: AccountLeases::VENUE, account_id: acc_id)
    lease_live = lease.present? && lease.expires_at.present? && lease.expires_at > Time.current

    render_json(
      account_id: acc_id,
      risk: {
        drawdown_pct: summary[:drawdown].round(4),
        max_drawdown_limit_pct: (max_drawdown * 100).round(2),
        drawdown_breached: current_dd_ratio >= max_drawdown,
        positions_count: summary[:positions_count],
        max_positions_limit: max_positions,
        position_limit_reached: summary[:positions_count] >= max_positions
      },
      lease: {
        held: lease_live,
        holder_id: lease_live ? lease.holder_id : nil,
        fence: lease_live ? lease.fence : nil,
        expires_at: lease_live ? lease.expires_at&.iso8601(3) : nil
      }
    )
  end
end
