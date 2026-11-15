# Single-writer leases for live accounts.
#
# A holder names itself (holder_id) and presents its fence on every write it makes to a live account. The venue refuses a
# write whose lease is held by someone else, has expired, or is no longer the presented fence. Acquisition is a single
# conditional UPDATE, so two concurrent acquirers cannot both win.
#
# All timing is judged on the database clock (now()). No client clock can extend or shorten a lease.
module AccountLeases
  VENUE = "paper_exchange".freeze
  MIN_TTL_SECONDS = 10
  MAX_TTL_SECONDS = 600
  DEFAULT_TTL_SECONDS = 30

  # How long a force release waits for in-flight writes to commit. Bounded, so a write wedged inside its transaction cannot hang
  # the operator's shell: the release gives up and changes nothing.
  FORCE_RELEASE_LOCK_TIMEOUT_SECONDS = 10

  # Another holder has the account. The caller learns who holds it, and until when.
  class Held < StandardError
    attr_reader :holder_label, :expires_at

    def initialize(holder_label:, expires_at:)
      @holder_label = holder_label
      @expires_at = expires_at
      super("account is leased by #{holder_label || "another holder"}")
    end
  end

  # The presented lease is not the live one: expired, released, superseded, or never granted.
  class Lost < StandardError; end

  # A write arrived with no holder or fence at all.
  class Required < StandardError; end

  # There is no live lease to release. An expired or released lease needs no force: the next acquire takes it.
  class NotHeld < StandardError; end

  # The account has no row. An eviction is audited against the account (risk_events references accounts), so it cannot be
  # recorded, and the lease lapses on its own within its TTL.
  class UnknownAccount < StandardError; end

  module_function

  # The requested TTL, or nil when it is not a whole number of seconds in range. Out-of-range is refused, never silently clamped.
  def ttl_seconds(raw)
    return DEFAULT_TTL_SECONDS if raw.nil? || raw.to_s.strip.empty?

    ttl = Integer(raw.to_s, exception: false)
    ttl if ttl && ttl.between?(MIN_TTL_SECONDS, MAX_TTL_SECONDS)
  end

  # Takes the lease when it is free or expired. The same holder asking again renews its own live lease instead, which is what
  # makes a retry after a lost response safe. Every new grant increments the fence.
  def acquire!(account_id:, holder_id:, label:, ttl_seconds:)
    ensure_row(account_id)

    granted = AccountLease
      .where(venue: VENUE, account_id: account_id)
      .where("holder_id IS NULL OR expires_at <= now()")
      .update_all([ <<~SQL.squish, holder_id, label, ttl_seconds ])
        holder_id = ?, holder_label = ?, fence = fence + 1, acquired_at = now(), heartbeat_at = now(),
        expires_at = now() + make_interval(secs => ?), released_at = NULL, updated_at = now()
      SQL
    return current!(account_id) if granted.positive?

    renewed = AccountLease
      .where(venue: VENUE, account_id: account_id, holder_id: holder_id)
      .where("expires_at > now()")
      .update_all([ "heartbeat_at = now(), expires_at = now() + make_interval(secs => ?), updated_at = now()", ttl_seconds ])
    return current!(account_id) if renewed.positive?

    holder = current!(account_id)
    raise Held.new(holder_label: holder.holder_label, expires_at: holder.expires_at)
  end

  # Extends a live lease. A lease that expired, was released, or was taken over is Lost, and the holder must stop writing.
  def heartbeat!(account_id:, holder_id:, fence:, ttl_seconds:)
    fence = presented_fence(holder_id, fence)
    renewed = AccountLease
      .where(venue: VENUE, account_id: account_id, holder_id: holder_id, fence: fence)
      .where("expires_at > now()")
      .update_all([ "heartbeat_at = now(), expires_at = now() + make_interval(secs => ?), updated_at = now()", ttl_seconds ])
    raise Lost, "the lease for #{account_id} is not held under fence #{fence}" unless renewed.positive?

    current!(account_id)
  end

  # Gives the lease back. Releasing a lease that is not held under this fence changes nothing and returns false.
  def release!(account_id:, holder_id:, fence:)
    fence = presented_fence(holder_id, fence)
    AccountLease
      .where(venue: VENUE, account_id: account_id, holder_id: holder_id, fence: fence)
      .update_all("holder_id = NULL, holder_label = NULL, released_at = now(), expires_at = now(), updated_at = now()")
      .positive?
  end

  # Operator eviction of the live holder, for a lease that will not lapse in time: a writer that crashed while its heartbeat kept
  # running, or one that is wedged and cannot be reached to release. Host-side only (lib/tasks/account_leases.rake): every agent
  # holds the same API key, so an HTTP route would let any agent evict another.
  #
  # The row is taken FOR UPDATE, so the release waits for every fenced write already in flight to commit under the fence it
  # checked. That wait is bounded: a write wedged inside its transaction raises ActiveRecord::LockWaitTimeout and releases nothing.
  # From the moment the release commits, the evicted holder's next write or heartbeat finds no lease under its fence.
  #
  # The fence is kept, so the next grant is fence + 1. The release and its LEASE_FORCE_RELEASED audit event commit together, and
  # the audit event references the account, so an account with no row cannot be evicted.
  def force_release!(account_id:, reason:, operator:, lock_timeout: FORCE_RELEASE_LOCK_TIMEOUT_SECONDS)
    reason = reason.to_s.strip
    operator = operator.to_s.strip
    raise ArgumentError, "a force release needs a reason" if reason.empty?
    raise ArgumentError, "a force release needs an operator" if operator.empty?
    raise ArgumentError, "lock_timeout must be a positive number of seconds" unless lock_timeout.to_f.positive?

    AccountLease.transaction do
      timeout_ms = (lock_timeout.to_f * 1000).round
      AccountLease.connection.execute(AccountLease.sanitize_sql_array([ "SET LOCAL lock_timeout = ?", "#{timeout_ms}ms" ]))
      row = AccountLease.lock("FOR UPDATE").find_by(venue: VENUE, account_id: account_id)
      raise NotHeld, "no live lease to release for #{account_id}" unless row && holder_live?(row.id)

      account_exists = Account.exists?(account_id: account_id)
      raise UnknownAccount, "#{account_id} has no account row, so the eviction cannot be audited" unless account_exists

      AccountLease.where(id: row.id).update_all(
        "holder_id = NULL, holder_label = NULL, released_at = clock_timestamp(), expires_at = clock_timestamp(), updated_at = clock_timestamp()"
      )
      RiskEvent.create!(
        account_id: account_id,
        event_type: "LEASE_FORCE_RELEASED",
        details: {
          venue: VENUE,
          reason: reason,
          operator: operator,
          released_holder_id: row.holder_id,
          released_holder_label: row.holder_label,
          released_fence: row.fence,
          acquired_at: row.acquired_at&.iso8601(3),
          expires_at_before_release: row.expires_at&.iso8601(3)
        }
      )
    end
  end

  # The guard every write to a live account passes through. Returns the live lease row, or raises Required or Lost.
  #
  # With lock: true the row is taken FOR SHARE, and the call must sit inside the transaction that makes the write. A takeover
  # needs the row's write lock, so it waits until that transaction commits. Liveness is read from clock_timestamp(), the real
  # time at which the lock is taken: now() would be the transaction's start, earlier than the lock.
  def assert_writable!(account_id:, holder_id:, fence:, lock: false)
    raise ArgumentError, "a locked lease check must run inside a transaction" if lock && !AccountLease.connection.transaction_open?

    fence = presented_fence(holder_id, fence)
    scope = AccountLease
      .where(venue: VENUE, account_id: account_id, holder_id: holder_id, fence: fence)
      .where("expires_at > clock_timestamp()")
    scope = scope.lock("FOR SHARE") if lock
    row = scope.first
    raise Lost, "the lease for #{account_id} is not held under fence #{fence}" unless row

    row
  end

  def ensure_row(account_id)
    now = Time.current
    AccountLease.insert_all(
      [ { venue: VENUE, account_id: account_id, fence: 0, created_at: now, updated_at: now } ],
      unique_by: %i[venue account_id]
    )
  end

  def current!(account_id)
    AccountLease.find_by!(venue: VENUE, account_id: account_id)
  end

  # The lease as the database judges it. Nil when no lease was ever granted for the account.
  def status(account_id:)
    row = AccountLease.find_by(venue: VENUE, account_id: account_id)
    return unless row

    { lease: row, live: holder_live?(row.id) }
  end

  # A holder is named and the lease has not lapsed. Both are judged on the database clock.
  def holder_live?(lease_id)
    AccountLease.where(id: lease_id).where.not(holder_id: nil).where("expires_at > clock_timestamp()").exists?
  end

  def presented_fence(holder_id, fence)
    raise Required, "X-Lease-Holder and X-Lease-Fence are required" if holder_id.blank? || fence.blank?

    value = Integer(fence.to_s, exception: false)
    raise Lost, "X-Lease-Fence must be a whole number" if value.nil?

    value
  end
end
