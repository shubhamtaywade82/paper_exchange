---
name: release-migration-gate
description: Gate deployment on migration compatibility and readiness without assuming database rollback equals application rollback.
family: rails
---

# Release Migration Gate

## Problem
A release can be application-compatible but migration-incompatible, or vice versa.

## Use when
Deployments include schema changes or migrations that affect runtime compatibility.

## Implementation procedure
1. Classify migrations as expand/contract/destructive.
2. Identify old/new application compatibility.
3. Run safe migration/preparation steps.
4. Verify schema state.
5. Deploy compatible application.
6. Verify readiness.
7. Contract only after old code is gone.
8. Document rollback limitations.

## Example

```bash
# CI gate: migrations in this release must be tolerable by the version still running.
# Destructive changes are only allowed in a migration explicitly marked as a contract phase.
changed=$(git diff --name-only --diff-filter=A origin/main...HEAD -- db/migrate)
status=0
for file in $changed; do
  if grep -Eq '\b(remove_column|rename_column|change_column|drop_table|rename_table)\b' "$file" &&
     ! grep -q '# release-phase: contract' "$file"; then
    echo "::error file=$file::destructive migration without a contract-phase marker"
    status=1
  fi
done
exit $status
```

## Failure modes
- automatic rollback after irreversible migration
- destructive migration before traffic drain
- readiness checked before schema is usable
- old job workers running against incompatible schema

## Testing
Exercise migration status and release-order checks.

## Review checklist
- migration compatibility known
- readiness gate exists
- rollback limitations explicit
- queued jobs considered


## Repository inspection

Inspect runtime/version, repository conventions, the owning boundary, neighboring implementations, and applicable tests before applying the pattern.


## Related skills

- rails-test-engineering
- ruby-tdd-refactoring
- rails-architecture
## Do not use when

Do not use when a release has no database migration or schema compatibility constraint.
