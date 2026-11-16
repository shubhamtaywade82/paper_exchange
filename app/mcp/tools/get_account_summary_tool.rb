# frozen_string_literal: true

class GetAccountSummaryTool < ApplicationMCPTool
  tool_name "get_account_summary"
  description "Fetch account balances, equity, locked margin, and drawdown for a paper trading account"

  property :account_id, type: "string", description: "Account identifier to inspect (default: test-account-1)"

  def perform
    acc_id = account_id.presence || "test-account-1"
    account = Account.find_by(account_id: acc_id)
    return render_json(error: "account_not_found", account_id: acc_id) unless account

    summary = Projections::PortfolioProjection.summary(acc_id)
    render_json(
      account_id: acc_id,
      currency: account.currency,
      wallet: {
        available: account.available_balance.to_s,
        locked: account.locked_margin.to_s,
        equity: summary[:equity].to_s,
        max_equity: summary[:max_equity].to_s,
        drawdown_pct: summary[:drawdown].round(4)
      },
      pnl: {
        realized: summary[:realized_pnl].to_s,
        unrealized: summary[:unrealized_pnl].to_s
      },
      positions_count: summary[:positions_count]
    )
  end
end
