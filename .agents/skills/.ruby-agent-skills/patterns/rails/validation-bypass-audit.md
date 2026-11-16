---
name: validation-bypass-audit
description: Use when a Rails invariant may be bypassed by direct or bulk write APIs.
family: rails
---

# Validation Bypass Audit

## Problem
Validation Bypass Audit needs an explicit contract so validation does not drift between model logic, database integrity, and consumers.

## Use when
- a model invariant changes and direct/bulk writers exist.

## Do not use when
- bypass APIs are banned without examining actual invariant ownership.

## Repository inspection
- direct/bulk writes;
- imports/admin tools/jobs;
- database constraints;
- repair scripts;
- tests.

## Implementation procedure
1. List write paths.
2. Mark which paths run validation.
3. Identify the authoritative invariant owner.
4. Move critical invariants to the database where needed.
5. Document intentional bypasses.
6. Test bypass paths separately.

## Example

```bash
# List every writer that skips validations/callbacks, then justify or fix each one.
git grep -nE '\b(update_all|update_column|update_columns|insert_all|upsert_all|delete_all|save\(validate: false\)|increment!|toggle!)\b' -- app lib db/seeds.rb |
  grep -v '^test/'

# Each hit gets one of:
#  - database constraint already guarantees the invariant (cite it), or
#  - comment "# bypasses validation: <why safe>", or
#  - replaced with a validated write.
```

## Failure modes
- bulk writes create invalid data;
- only web requests are protected;
- database constraints are missing.

## Testing
- representative bypass writer;
- database rejection;
- intentional maintenance/import path.

## Review checklist
- [ ] all writers considered
- [ ] authority is explicit
- [ ] critical invariants survive bypasses

## Related skills
- rails-validations
- rails-active-record
- rails-database-engineering
- rails-test-engineering
