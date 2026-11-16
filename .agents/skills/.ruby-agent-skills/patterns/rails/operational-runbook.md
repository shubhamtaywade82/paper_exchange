---
name: operational-runbook
description: Write operator runbooks as bounded decision procedures with diagnostics, mitigations, recovery checks, and rollback paths.
family: rails
---

# Operational Runbook

## Problem
Narrative documentation is difficult to execute under incident pressure and often omits stop conditions or recovery verification.

## Use when
- creating or repairing an incident runbook;
- documenting a repeated operational failure;
- exposing controlled production remediation.

## Do not use when
- documenting conceptual architecture only;
- no operator action is expected.

## Repository inspection
Inspect existing on-call docs, access controls, CLI/admin tooling, dashboards, escalation paths, rollback mechanics, and recovery objectives.

## Implementation procedure
1. State purpose and affected contract. 2. Define prerequisites. 3. Link detection signals. 4. Provide diagnostic steps with expected evidence. 5. Add decision branches. 6. Define mitigation and stop conditions. 7. Define recovery verification. 8. Define undo/escalation.

## Example

```markdown
## Runbook: Solid Queue backlog > 10k jobs

**Trigger:** alert `queue-backlog-high` (ready jobs > 10,000 for 10 min).
**Owner:** platform on-call.

1. Check: `bin/rails runner 'puts SolidQueue::ReadyExecution.group(:queue_name).count'`
   Stop if backlog is draining (count falling over 5 min).
2. Check workers: `kamal app details -r job` — expect 6 running.
   If fewer: `kamal app boot -r job`. Verify count again.
3. If one queue dominates, pause its producer flag: `Flipper.disable(:bulk_export)`.
   Reversible: `Flipper.enable(:bulk_export)`.
4. **Do not** delete jobs; they are durable business work.

**Recovered when:** ready jobs < 1,000 and `queue.oldest_ready_seconds` < 60 for 15 min.
```

## Failure modes
- unbounded destructive commands;
- missing permissions;
- no rollback;
- no success criteria;
- commands copied from stale runtime assumptions.

## Testing
Exercise the runbook in a safe environment or game day. Verify commands, expected outputs, decision branches, and recovery checks.

## Review checklist
- [ ] safe prerequisites; - [ ] bounded commands; - [ ] decision points; - [ ] undo path; - [ ] recovery verification; - [ ] owner/escalation.

## Related skills
rails-incident-engineering, rails-production-runtime, rails-reliability-engineering, rails-security