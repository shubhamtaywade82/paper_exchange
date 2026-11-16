---
name: distributed-boundary-readiness
description: Distributed Boundary Readiness Contract
family: architecture
---
# Distributed Boundary Readiness Contract

## Problem
Extracting a component into another process without operational readiness creates a distributed monolith.

## Use when
Considering microservice or independent-process extraction.

## Do not use when
The workload is comfortably within an in-process boundary and no deployment/failure isolation need exists.

## Repository inspection
Inspect data ownership, API/message contracts, latency budget, retries, observability, deployment, secrets, failure recovery, and compatibility.

## Implementation procedure
Define stable contract, independent ownership, failure model, idempotency, rollout, and data migration before extraction.

## Example

```markdown
## Extraction readiness: `notifications` service

- [x] Stable API contract (`POST /v1/notifications`, versioned, idempotency-key required)
- [x] Owns its data (`notifications` database; the monolith no longer writes it)
- [x] Failure model: monolith enqueues via outbox; delivery retries are bounded; dead letters owned by the comms team
- [x] Observability: request id propagated; latency/error SLO dashboards exist
- [ ] Rollout: shadow traffic for 2 weeks, then 10% → 100% with a flag
- [ ] Rollback: flag off returns to in-process delivery; tested in staging

Not ready until every box is checked.
```

## Failure modes
Partial failure, synchronous coupling, distributed transaction assumptions, incompatible deploys.

## Testing
Test duplicate/delayed failures, compatibility, recovery, and deployment sequencing before extraction.

## Review checklist
[ ] contract [ ] data owner [ ] failure model [ ] rollout [ ] recovery

## Related skills
rails-staff-principal-architecture, rails-distributed-systems, rails-release-engineering