---
name: rollback-rollforward
description: Decide and execute rollback or roll-forward based on durable-state compatibility, external side effects, and recoverability.
family: rails
---

# Rollback or Roll-Forward

## Problem
Rollback is unsafe when the current durable state or external contracts are incompatible with the previous application version.

## Use when
- defining failed-release recovery;
- introducing irreversible migrations;
- choosing recovery direction during a release incident.

## Do not use when
- release recovery semantics are already fixed by an external platform contract and no application decision exists.

## Repository inspection
Inspect current/previous artifacts, migration state, queued jobs, external side effects, data reconciliation, feature flags, and incident/runbook controls.

## Implementation procedure
1. Determine current durable state. 2. Check previous artifact compatibility. 3. Identify irreversible/external effects. 4. Select rollback or forward fix. 5. Define verification. 6. Record recovery evidence.

## Example

```markdown
## Rollback decision for release 2026-09-27.3

| Question                                                      | Answer | Consequence                        |
|---------------------------------------------------------------|--------|------------------------------------|
| Did the release run a contract (destructive) migration?       | No     | previous code still reads schema   |
| Did it write data the previous version cannot read?           | Yes — new `status = "on_hold"` rows | old code raises on unknown enum |
| Did it emit external side effects (emails, charges, webhooks)?| Yes    | cannot be undone by rollback       |
| Are queued jobs serialized in a new format?                   | No     | old workers can run them           |

**Decision:** roll forward with a fix (old version cannot read `on_hold`). Rollback would
only be safe after a data fix mapping `on_hold` → `pending`, which loses information.
```

## Failure modes
- assuming application rollback undoes schema/data changes;
- ignoring already-emitted external messages or charges;
- no reconciliation plan;
- no recovery verification.

## Testing
Test recovery against representative expand/contract and partially-applied release scenarios.

## Review checklist
- [ ] compatibility; - [ ] external effects; - [ ] data state; - [ ] recovery direction; - [ ] verification.

## Related skills
rails-release-engineering, rails-production-runtime, rails-database-engineering, rails-incident-engineering, rails-distributed-systems