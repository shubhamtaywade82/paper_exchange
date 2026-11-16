---
name: distributed-lock
description: Coordinate cross-process ownership with an expiring distributed lock or lease only when simpler ownership primitives are insufficient.
family: rails
---

# Distributed Lock

## Problem

Multiple independent processes may perform the same mutually exclusive work, but the invariant cannot be enforced by one process-local lock.

## Use when

A lock/lease is genuinely required to coordinate ownership across processes, workers, hosts, or services.

## Do not use when

A database constraint, atomic update, row lock, keyed queue, concurrency-controlled job, or single authoritative writer can enforce the invariant.

## Repository inspection

Inspect lock backend semantics, lease TTL, renewal, failure behavior, clock assumptions, network partitions, fencing/token support, contention, and the actual invariant.

## Implementation procedure

1. State the invariant requiring exclusion.
2. Prove simpler database/queue primitives are insufficient.
3. Define lock key/namespace.
4. Define owner identity and lease duration.
5. Define acquisition timeout and contention backoff.
6. Define renewal and lease-loss behavior.
7. Use fencing/token semantics when stale owners can still mutate state.
8. Release safely without deleting another owner's lock.
9. Keep the protected work bounded and preferably idempotent.
10. Monitor contention and expired leases.

## Example

```ruby
# PostgreSQL advisory lock: one process at a time runs the nightly
# settlement, across every host, and the lock is released if the process dies.
class Settlement
  LOCK_KEY = 42_001

  def self.run_exclusive
    ApplicationRecord.connection.transaction do
      acquired = ApplicationRecord.connection.select_value("SELECT pg_try_advisory_xact_lock(#{LOCK_KEY})")
      return :already_running unless acquired

      new.call # lock held for this transaction only
    end
  end
end
```

## Failure modes

- local mutex used across hosts
- lock without expiration
- lock without ownership verification
- stale owner continues after lease expiry
- clock/lease assumptions not understood
- long critical sections
- lock used as a substitute for idempotency

## Testing

Test contention, lease expiry, renewal loss, stale-owner rejection, acquisition timeout, process crash, and duplicate work recovery.

## Review checklist

- [ ] simpler primitive ruled out
- [ ] owner identity explicit
- [ ] lease expiry explicit
- [ ] stale owner behavior safe
- [ ] fencing used when required
- [ ] contention bounded
- [ ] protected work remains safe to retry

## Related skills

- rails-distributed-systems
- ruby-concurrency
- rails-database-engineering
- rails-production-runtime

## Related patterns

- concurrency-controlled-job
- transaction-lock-boundary
- idempotent-job
