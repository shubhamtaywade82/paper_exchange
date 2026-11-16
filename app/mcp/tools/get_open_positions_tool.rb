# frozen_string_literal: true

class GetOpenPositionsTool < ApplicationMCPTool
  tool_name "get_open_positions"
  description "Fetch active leveraged and unleveraged open positions for an account"

  property :account_id, type: "string", description: "Account identifier to inspect (default: test-account-1)"

  def perform
    acc_id = account_id.presence || "test-account-1"
    account = Account.find_by(account_id: acc_id)
    return render_json(error: "account_not_found", account_id: acc_id) unless account

    positions = Projections::PositionProjection.for_account(acc_id)
    render_json(
      account_id: acc_id,
      count: positions.size,
      positions: positions
    )
  end
end
