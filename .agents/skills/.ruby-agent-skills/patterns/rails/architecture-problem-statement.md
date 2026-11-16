---
name: architecture-problem-statement
description: Architecture Problem Statement Contract
family: architecture
---
# Architecture Problem Statement Contract

## Problem
Architecture work fails when a proposed structure solves a vague discomfort instead of a concrete system problem.

## Use when
Starting or reviewing a material architecture change.

## Do not use when
A localized feature fits an existing boundary without structural change.

## Repository inspection
Inspect incidents, change coupling, dependency graph, performance/reliability/security constraints, and actual pain.

## Implementation procedure
State the problem, affected invariants, measurable cost, and why existing boundaries are insufficient.

## Example

```markdown
**Problem:** Checkout p95 latency is 2.8 s (SLO 800 ms) during sales; 70% of
the time is spent in synchronous tax and fraud API calls inside the request.

**Invariants to keep:** an order is charged at most once; tax is final at charge time.

**Constraints:** PostgreSQL primary only; same deploy pipeline; payments team owns checkout.

**Evidence:** APM traces from 2026-09-15 sale (attached); provider latency p95 900 ms each.

**Not the problem:** controller size, the service-object folder layout.
```

## Failure modes
Architecture theatre, overbuilding, solving hypothetical scale, unclear success criteria.

## Testing
Review whether the stated problem is supported by repository evidence.

## Review checklist
[ ] problem concrete [ ] evidence [ ] invariants [ ] success criteria

## Related skills
rails-staff-principal-architecture, rails-architecture