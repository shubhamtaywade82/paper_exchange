---
name: tenant-isolation-review
description: Verify tenant isolation across request, persistence, jobs, messages, caches, exports, and administrative paths.
family: rails
---

# Tenant Isolation Review

## Problem

A multi-tenant system can accidentally expose one tenant's data through a secondary execution path even when normal controllers appear scoped.

## Use when

Tenant/account/workspace boundaries affect data access or privileged operations.

## Do not use when

The application has no tenant-scoped security boundary.

## Repository inspection

Inspect tenant identity source, database constraints, default scopes/query objects, policies, jobs, events/messages, cache keys, exports, admin tooling, and direct model access.

## Implementation procedure

1. Identify authoritative tenant identity.
2. Reject client-supplied tenant switching unless explicitly authorized.
3. Enforce tenant scope at the owning persistence/query boundary.
4. Propagate tenant context explicitly to jobs/messages.
5. Include tenant identity in security-sensitive cache keys.
6. Audit exports/admins/callbacks and background paths.
7. Add cross-tenant denial tests.
8. Review database-level guarantees where practical.

## Example

```markdown
## Tenant isolation review: `Report` export

| Entry point                          | Tenant source                    | Scoped? | Test                               |
|--------------------------------------|----------------------------------|---------|------------------------------------|
| `ReportsController#show`             | `Current.account`                | ✅      | cross-tenant id → 404              |
| `ExportReportJob.perform(report_id)` | `Report.find(report_id)`         | ❌ → re-check `report.account` membership of `requested_by` | job test with revoked member |
| `reports:export_all` rake task       | `ENV["ACCOUNT_ID"]`              | ✅ explicit, audited | task test                    |
| Action Cable `ReportChannel`         | `params[:report_id]`             | ❌ → `stream_for` only after policy check | channel test          |
| Report cache                         | key `[report, :pdf]`             | ✅ record-scoped key   | —                        |
| Search index                         | `account_id` filter on every query| ✅     | search test with two tenants       |
```

## Failure modes

- controller-only scope
- missing tenant context in a job
- cache key collision across tenants
- export/admin bypass
- global record lookup by ID

## Testing

Test cross-tenant reads/writes, jobs, messages, caches, exports, and privileged operations where applicable.

## Review checklist

- [ ] tenant identity authoritative
- [ ] persistence/query boundary protected
- [ ] async paths carry scope
- [ ] cache isolation
- [ ] admin/export reviewed
- [ ] cross-tenant regression exists

## Related skills

- rails-security-engineering
- rails-security
- rails-database-engineering
- rails-distributed-systems
