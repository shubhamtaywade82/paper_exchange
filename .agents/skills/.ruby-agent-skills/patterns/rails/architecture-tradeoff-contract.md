---
name: architecture-tradeoff-contract
description: Architecture Tradeoff Contract
family: architecture
---
# Architecture Tradeoff Contract

## Problem
A design decision is incomplete when it states benefits but hides latency, operational, migration, security, or team costs.

## Use when
Any material architecture choice with more than one plausible option.

## Do not use when
A local implementation choice with negligible long-term consequence.

## Repository inspection
Inspect constraints and likely alternatives including no-change option.

## Implementation procedure
Compare options across correctness, complexity, performance, reliability, security, migration cost, operations, and ownership.

## Example

```markdown
| Option | Latency | Operations | Migration | Security | Team cost |
|---|---|---|---|---|---|
| Async tax + fraud via jobs, confirm by webhook | p95 ~300 ms in request | queue depth to monitor | 2 releases, expand/contract on orders.status | webhook signatures to verify | payments team, 3 weeks |
| Keep synchronous, add provider timeouts | p95 ~1.2 s | none new | none | unchanged | 2 days |
| Extract checkout service | p95 unknown (+network hop) | new deploy, DB, on-call | months, dual writes | new service credentials | new team |

Chosen: async jobs. Accepted costs: eventual confirmation UI state and queue monitoring.
```

## Failure modes
Local optimization creates system-wide cost, hidden complexity, unjustified scale assumptions.

## Testing
Require an explicit decision record or review artifact where the repository expects one.

## Review checklist
[ ] alternatives [ ] costs [ ] system effects [ ] no-change considered

## Related skills
rails-staff-principal-architecture, agent-workflow