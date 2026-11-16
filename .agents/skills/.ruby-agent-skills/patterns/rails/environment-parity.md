---
name: environment-parity
description: Identify deliberate environment differences that can invalidate release evidence and make them explicit release concerns.
family: rails
---

# Environment Parity

## Problem
Staging and production differences can make otherwise strong test evidence misleading.

## Use when
- debugging staging-only or production-only failures;
- reviewing release pipelines;
- changing runtime infrastructure.

## Do not use when
- environments are already equivalent for the behavior under review and no relevant drift exists.

## Repository inspection
Compare runtime versions, dependency lock state, databases, queue/broker, providers, flags, limits, process topology, and proxy behavior.

## Implementation procedure
1. Enumerate differences. 2. Classify which can affect the release. 3. Reproduce relevant production behavior or use production-like staging. 4. Document deliberate exceptions. 5. Add a gate/test for material drift.

## Example

```markdown
| Dimension          | Staging                     | Production                  | Parity risk / compensating check                  |
|--------------------|-----------------------------|-----------------------------|---------------------------------------------------|
| Ruby / Rails       | 3.4.4 / 8.0.2 (same image)  | 3.4.4 / 8.0.2               | none — same artifact digest promoted              |
| PostgreSQL         | 16, 20 GB snapshot          | 16, 1.2 TB                  | migrations timed against a prod-sized restore     |
| Puma               | 1 worker × 5 threads        | 4 workers × 5 threads       | load test at prod concurrency before release      |
| Queue              | Solid Queue, 1 worker       | Solid Queue, 6 workers      | duplicate-execution tests cover concurrency       |
| Payments provider  | sandbox                     | live                        | contract tests against recorded live responses    |
| Feature flags      | all on                      | per-tenant                  | flag-off path covered in request tests            |
```

## Failure modes
- assuming staging proves production;
- undocumented provider differences;
- different resource limits;
- different feature flags or database capabilities.

## Testing
Use a parity report or targeted integration checks to assert material configuration/runtime equivalence.

## Review checklist
- [ ] runtime parity; - [ ] dependency parity; - [ ] data/DB behavior; - [ ] provider parity; - [ ] resource parity; - [ ] deliberate exceptions.

## Related skills
rails-release-engineering, rails-production-runtime, rails-api-integration
