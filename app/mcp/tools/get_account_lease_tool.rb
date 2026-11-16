# frozen_string_literal: true

class GetAccountLeaseTool < ApplicationMCPTool
  tool_name "get_account_lease"
  description "Account single-writer lease status: holder ID, fence counter, expiry, and active status. Read-only."

  property :account_id, type: "string", description: "Account identifier (default: test-account-1)"
  property :venue, type: "string", description: "Venue name (default: paper_exchange)"

  def perform
    acc_id = account_id.presence || "test-account-1"
    v = venue.presence || "paper_exchange"
    lease = ::AccountLease.find_by(account_id: acc_id, venue: v)

    return render_json(account_id: acc_id, venue: v, held: false, fence: 0) unless lease

    now = Time.current
    is_active = lease.holder_id.present? && lease.expires_at.present? && lease.expires_at > now && lease.released_at.nil?

    render_json(
      account_id: lease.account_id,
      venue: lease.venue,
      held: is_active,
      holder_id: lease.holder_id,
      holder_label: lease.holder_label,
      fence: lease.fence,
      acquired_at: lease.acquired_at&.iso8601,
      heartbeat_at: lease.heartbeat_at&.iso8601,
      expires_at: lease.expires_at&.iso8601,
      released_at: lease.released_at&.iso8601
    )
  end
end
