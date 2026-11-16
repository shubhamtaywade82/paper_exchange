---
name: architectural-migration-contract
description: Architectural Migration Contract
family: architecture
---
# Architectural Migration Contract

## Problem
Large architectural rewrites create prolonged dual systems and unclear rollback.

## Use when
Migrating responsibility between modules, engines, services, or data owners.

## Do not use when
A small local refactor with no staged compatibility concern.

## Repository inspection
Inspect old/new paths, traffic/workload, schema ownership, feature flags, rollback, and cleanup conditions.

## Implementation procedure
Use incremental target introduction, bounded migration, compatibility period, verification, cutover, and removal.

## Example

```markdown
## Migration: move invoicing from `app/models/billing_*` into the `Billing` module

| Stage | Change | Compatibility | Exit criterion |
|---|---|---|---|
| 1 | Add `Billing.charge(order)` facade; old callers unchanged | both paths live | facade covered by tests |
| 2 | Move callers to `Billing.charge` one controller/job at a time | old models still loadable | `git grep BillingInvoice app/` returns nothing outside `Billing` |
| 3 | Mark internals `private_constant`; add fitness check | external access fails CI | check green for 2 weeks |
| 4 | Delete compatibility aliases | none | aliases removed, check still green |

Rollback: every stage is a normal deploy; stages 1–3 can be reverted independently.
```

## Failure modes
Dual-write divergence, orphaned paths, migration dead ends, irreversible cutover.

## Testing
Test each migration stage and rollback/recovery conditions.

## Review checklist
[ ] stages [ ] compatibility [ ] verification [ ] cutover [ ] cleanup

## Related skills
rails-staff-principal-architecture, rails-release-engineering