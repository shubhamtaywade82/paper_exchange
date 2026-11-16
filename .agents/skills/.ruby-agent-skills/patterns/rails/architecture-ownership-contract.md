---
name: architecture-ownership-contract
description: Architecture Ownership Contract
family: architecture
---
# Architecture Ownership Contract

## Problem
A technical boundary without a stable operational owner becomes an unmaintained dependency sink.

## Use when
Introducing a subsystem, shared component, engine, service, or platform boundary.

## Do not use when
A local implementation with existing clear ownership.

## Repository inspection
Inspect codeowners/team docs, deployment ownership, incident/runbook responsibilities, and compatibility expectations.

## Implementation procedure
Assign behavior, schema, operational, incident, and contract ownership explicitly.

## Example

```yaml
# config/ownership.yml — every boundary has a team, an on-call rotation, and
# the paths it owns; CODEOWNERS is generated from this file.
billing:
  team: payments
  on_call: payments-primary
  paths: [app/billing/**, app/jobs/billing/**, db/migrate/*billing*]
  public_entry_points: [Billing.charge, Billing.refund]
search:
  team: discovery
  on_call: discovery-primary
  paths: [app/search/**, config/elasticsearch/**]
  public_entry_points: [Search.query]
```

## Failure modes
Orphaned subsystem, unclear escalation, unmanaged compatibility.

## Testing
Verify ownership metadata/documentation matches actual responsibility.

## Review checklist
[ ] behavior owner [ ] data owner [ ] ops owner [ ] compatibility owner

## Related skills
rails-staff-principal-architecture, rails-incident-engineering