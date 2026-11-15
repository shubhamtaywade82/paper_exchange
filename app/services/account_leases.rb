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

  def presented_fence(holder_id, fence)
    raise Required, "X-Lease-Holder and X-Lease-Fence are required" if holder_id.blank? || fence.blank?

    value = Integer(fence.to_s, exception: false)
    raise Lost, "X-Lease-Fence must be a whole number" if value.nil?

    value
  end
end
