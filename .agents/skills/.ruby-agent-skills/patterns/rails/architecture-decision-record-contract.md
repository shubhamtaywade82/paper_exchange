---
name: architecture-decision-record-contract
description: Architecture Decision Record Contract
family: architecture
---
# Architecture Decision Record Contract

## Problem
Important architecture decisions are repeatedly revisited when context and tradeoffs are not recorded.

## Use when
A decision materially changes boundaries, dependencies, data ownership, or deployment shape.

## Do not use when
A routine implementation detail with no durable architectural consequence.

## Repository inspection
Inspect existing architecture docs/ADRs and repository conventions.

## Implementation procedure
Record context, problem, constraints, alternatives, decision, consequences, migration, and review trigger without duplicating source code.

## Example

```markdown
# ADR 0012: Keep background jobs on Solid Queue instead of adding Sidekiq

- Status: accepted (2026-09-10)
- Context: 40 jobs/s peak, PostgreSQL already provisioned; no Redis today.
- Decision: use Solid Queue on the primary database with a separate queue DB pool of 10.
- Alternatives rejected: Sidekiq (adds Redis to operate and secure); GoodJob (no advantage over the framework default here).
- Consequences: job throughput is bounded by database capacity; queue tables need vacuum monitoring.
- Review trigger: sustained > 300 jobs/s, or queue latency p95 > 30 s for a week.
```

## Failure modes
Decision reversals lose context, rejected alternatives forgotten, documentation drifts.

## Testing
Review ADR against implementation and migration evidence.

## Review checklist
[ ] context [ ] alternatives [ ] consequences [ ] migration [ ] review trigger

## Related skills
rails-staff-principal-architecture, agent-workflow