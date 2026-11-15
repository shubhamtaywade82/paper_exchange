# frozen_string_literal: true

# Operator tools for the single-writer account lease. Host-side only: they act on the database, never over HTTP. Every agent
# holds the same API key, so an HTTP force-release would let any agent evict another.
#
#   ACCOUNT_ID=acc-1 bin/rails account_leases:status
#   ACCOUNT_ID=acc-1 OPERATOR=jane REASON="pid 4123 wedged; confirmed dead on host" bin/rails account_leases:force_release
namespace :account_leases do
  desc "Show the lease for ACCOUNT_ID (read-only)"
  task status: :environment do
    account_id = ENV.fetch("ACCOUNT_ID", "").strip
    abort "ACCOUNT_ID is required" if account_id.empty?

    snapshot = AccountLeases.status(account_id: account_id)
    if snapshot.nil?
      puts "#{account_id}: no lease has ever been granted"
    else
      lease = snapshot[:lease]
      state = if snapshot[:live]
        "LIVE"
      elsif lease.holder_id
        "EXPIRED (still names its holder; the next acquire takes it)"
      else
        "FREE"
      end
      puts "account:   #{account_id}"
      puts "state:     #{state}"
      puts "holder:    #{lease.holder_label.presence || "-"} (#{lease.holder_id || "none"})"
      puts "fence:     #{lease.fence}"
      puts "acquired:  #{lease.acquired_at&.iso8601(3) || "-"}"
      puts "heartbeat: #{lease.heartbeat_at&.iso8601(3) || "-"}"
      puts "expires:   #{lease.expires_at&.iso8601(3) || "-"}"
      puts "released:  #{lease.released_at&.iso8601(3) || "-"}"
    end
  end

  desc "Force-release the live lease for ACCOUNT_ID; needs REASON and OPERATOR, audited as LEASE_FORCE_RELEASED"
  task force_release: :environment do
    account_id = ENV.fetch("ACCOUNT_ID", "").strip
    reason = ENV.fetch("REASON", "").strip
    operator = ENV.fetch("OPERATOR", "").strip
    abort "ACCOUNT_ID is required" if account_id.empty?
    abort "REASON is required: say why the live holder is being evicted" if reason.empty?
    abort "OPERATOR is required: name the person answerable for the eviction" if operator.empty?

    event = AccountLeases.force_release!(account_id: account_id, reason: reason, operator: operator)
    released = event.reload.details
    puts "released #{released["released_holder_label"].presence || released["released_holder_id"]} (fence #{released["released_fence"]}) on #{account_id}"
    puts "the next grant takes fence #{released["released_fence"].to_i + 1}; audit event #{event.id}"
  rescue AccountLeases::NotHeld, AccountLeases::UnknownAccount => e
    abort e.message
  rescue ActiveRecord::LockWaitTimeout
    abort "a write still holds the lease row for #{account_id}; nothing was released. Check pg_stat_activity and retry"
  end
end
