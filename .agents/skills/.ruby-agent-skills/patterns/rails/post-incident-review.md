---
name: post-incident-review
description: Convert incident evidence into a small set of owned, testable engineering improvements without turning the review into blame or vague action items.
family: rails
---

# Post-Incident Review

## Problem
Incident reviews become low-value when they are narratives without evidence or produce many unowned follow-ups.

## Use when
- closing a material incident;
- reviewing recurring failures;
- turning an operational finding into engineering work.

## Do not use when
- the event is only a local development defect with no operational learning.

## Repository inspection
Inspect incident records, existing tests, telemetry, alerts, runbooks, reliability objectives, security controls, and previous action items.

## Implementation procedure
1. State the affected contract. 2. Build the evidence-backed timeline. 3. Describe causal chain with uncertainty. 4. Identify control gaps. 5. Select a small number of high-leverage actions. 6. Assign owners. 7. Define verification. 8. Update runbooks/tests/telemetry/design.

## Example

```markdown
## Post-incident review: INC-2026-031 (checkout latency)

**Impact:** 17 min, checkout p95 > 8 s, 4.2 % of attempts failed (≈ 1,900 orders).
**Trigger:** release `a1b2c3d` added a provider call inside `Order#recalculate!` while holding a row lock.
**Contributing:** no lock-wait metric; load test used 1/10th production concurrency.
**Root cause (evidence):** pg_stat_activity snapshot 09:21 shows 38 lock waits on `orders`; reproduced in staging.

| Action                                            | Owner     | Due        | Verification                         |
|---------------------------------------------------|-----------|------------|--------------------------------------|
| Move provider call outside `with_lock`            | payments  | 2026-10-04 | regression test holds no lock on call|
| Alert on `pg_locks` wait > 5 s                    | platform  | 2026-10-11 | alert fires in staging drill         |
| Load test at production concurrency pre-release   | platform  | 2026-10-18 | release checklist gate               |
```

## Failure modes
- blame-focused conclusions;
- unverified root cause;
- dozens of vague tasks;
- actions without ownership;
- actions without proof of completion.

## Testing
Each technical action should map to an executable test, telemetry assertion, runbook check, or design verification where practical.

## Review checklist
- [ ] evidence-backed timeline; - [ ] causal uncertainty labeled; - [ ] control gaps; - [ ] owner; - [ ] verification; - [ ] durable artifact updated.

## Related skills
rails-incident-engineering, rails-reliability-engineering, rails-observability, rails-test-engineering