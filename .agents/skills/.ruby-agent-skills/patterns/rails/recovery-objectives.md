---
name: recovery-objectives
description: Define and verify RTO, RPO, restore, failover, reconciliation, and post-recovery validation for critical Rails workloads.
family: rails
---

# Recovery Objectives

## Problem

A service is considered "recovered" when processes boot, even though data, dependencies, or business workflows may still be inconsistent.

## Use when

Planning disaster recovery, backups/restores, failover, regional incidents, data corruption recovery, or major dependency outages.

## Do not use when

The component has no durable state or recovery is entirely owned by an external platform with a verified contract.

## Repository inspection

Inspect databases, backups, replicas, object storage, deployment artifacts, secrets, dependencies, recovery scripts, reconciliation jobs, and ownership/runbooks.

## Implementation procedure

1. Identify critical data and user journeys.
2. Define RTO and RPO.
3. Identify authoritative recovery sources.
4. Document restore/failover sequence.
5. Define post-restore validation.
6. Define reconciliation for asynchronous/downstream state.
7. Test recovery with representative data and dependencies.
8. Record actual recovery time and data-loss window.

## Example

```markdown
## Recovery objectives

| Capability        | RTO    | RPO      | Mechanism                              | Verified by                          |
|-------------------|--------|----------|----------------------------------------|--------------------------------------|
| Checkout          | 30 min | 0        | Multi-AZ PostgreSQL, synchronous standby | quarterly failover drill (last: 2026-08-14, 11 min) |
| Order history     | 4 h    | 5 min    | WAL archiving + PITR                   | monthly restore to staging + row counts |
| Search            | 24 h   | rebuild  | reindex from PostgreSQL                | reindex job timing (3 h 10 m)        |
| Uploaded files    | 24 h   | 0        | S3 versioning + cross-region replication | restore sample of 100 objects        |

"Recovered" = SLI back within SLO **and** reconciliation reports zero missing orders/payments.
```

## Failure modes

- backup exists but restore is untested
- restore cannot run without unavailable dependencies
- schema/code incompatible with restored data
- downstream state remains divergent
- RPO is assumed from backup frequency alone

## Testing

Run controlled restore/failover exercises. Verify application behavior, critical invariants, reconciliation, and measured RTO/RPO.

## Review checklist

- [ ] critical data identified
- [ ] RTO explicit
- [ ] RPO explicit
- [ ] restore/failover steps documented
- [ ] validation explicit
- [ ] reconciliation explicit
- [ ] recovery measured

## Related skills

- rails-reliability-engineering
- rails-database-engineering
- rails-production-runtime
- rails-distributed-systems
