---
name: production-runbook-command-contract
description: Production Runbook Command Contract
family: rails
---
# Production Runbook Command Contract

## Problem
Operators repeat unsafe manual steps when a maintenance command has no documented invocation, prerequisites, or rollback path.

## Use when
Production operational commands intended for repeated use or incident response.

## Do not use when
Temporary local experimentation with no shared operational responsibility.

## Repository inspection
Inspect runbooks, deployment access, command arguments, environment prerequisites, approvals, and rollback instructions.

## Implementation procedure
Document invocation, prechecks, dry-run, expected output, stop conditions, recovery, and verification.

## Example

```markdown
## `bin/rails billing:regenerate_invoice`

| Field          | Value                                                                        |
|----------------|------------------------------------------------------------------------------|
| Purpose        | Rebuild one invoice's PDF after a template fix                               |
| Invocation     | `INVOICE_ID=123 DRY_RUN=0 kamal app exec -r job 'bin/rails billing:regenerate_invoice'` |
| Prerequisites  | Invoice is `issued`; template release deployed; ACTOR set to your email       |
| Default        | `DRY_RUN=1` prints the diff and changes nothing                              |
| Idempotent     | Yes — rerun overwrites the same attachment                                   |
| Verification   | `Invoice.find(123).pdf.blob.created_at` is after the run; customer link works|
| Rollback       | Previous blob retained 7 days: `Invoice.find(123).restore_previous_pdf!`      |
| Stop if        | Invoice is `paid` and the amount would change — escalate to billing          |
```

## Failure modes
Wrong arguments, missing approvals, incomplete recovery, ambiguous success.

## Testing
Test the documented command sequence in a safe environment and compare evidence with the runbook.

## Review checklist
[ ] invocation [ ] prerequisites [ ] stop conditions [ ] recovery [ ] verification

## Related skills
rails-operational-tasks-maintenance, rails-incident-engineering, rails-release-engineering