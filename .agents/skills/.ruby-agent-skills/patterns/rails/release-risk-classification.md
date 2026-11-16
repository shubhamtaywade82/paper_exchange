---
name: release-risk-classification
description: Classify release risk from reversibility, blast radius, contract, data, security, and runtime impact before choosing release gates.
family: rails
---

# Release Risk Classification

## Problem
Uniform release procedures either over-gate trivial changes or under-protect high-risk changes.

## Use when
- planning a release;
- selecting gates or rollout stages;
- reviewing an exceptional release.

## Do not use when
- the change has no release concern;
- an existing repository risk rubric already owns the decision and only needs to be applied.

## Repository inspection
Inspect existing change classifications, deployment approvals, migration policies, security review triggers, and incident history.

## Implementation procedure
1. Classify code/data/contract/security/runtime impact. 2. Determine reversibility. 3. Estimate blast radius. 4. Identify overlap with old/new processes. 5. Select proportional gates and exposure. 6. Record residual risk and required approval.

## Example

```markdown
| Risk class | Examples                                                       | Required gates                                   |
|------------|----------------------------------------------------------------|--------------------------------------------------|
| Low        | copy change, CSS, log field, dependency patch with no API use  | CI green                                         |
| Medium     | new endpoint behind flag, additive migration, new job          | CI + staging smoke + flag default off            |
| High       | payments/auth code, data backfill, column removal, Rails upgrade| CI + staging soak + progressive exposure + owner sign-off + rollback plan |
| Irreversible| data deletion, external side effects with no undo             | High gates + dry run output reviewed + backup verified |
```

## Failure modes
- one gate set for all changes;
- ignoring irreversibility;
- treating small diffs as low risk without behavioral analysis;
- unowned exceptions.

## Testing
Test classification rules with representative low-, medium-, and high-risk release cases.

## Review checklist
- [ ] reversibility; - [ ] blast radius; - [ ] contract impact; - [ ] data/security impact; - [ ] gates proportional.

## Related skills
rails-release-engineering, rails-production-runtime, rails-database-engineering, rails-security-engineering, rails-reliability-engineering