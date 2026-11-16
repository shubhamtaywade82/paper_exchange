---
name: incident-triage
description: Structure production incident triage around user impact, scope, onset, evidence, hypotheses, and next safe actions.
family: rails
---

# Incident Triage

## Problem
Production failures often generate many noisy signals. An agent needs a repeatable way to establish what is actually affected before selecting a mitigation.

## Use when
- a production alert or symptom needs initial classification;
- scope, onset, or severity is unclear;
- several plausible causes exist.

## Do not use when
- the task is ordinary local debugging with no operational impact;
- the root cause is already proven and the task is only implementation.

## Repository inspection
Inspect existing SLOs, severity conventions, alert definitions, request/job/message identifiers, deployment markers, dashboards, and ownership metadata.

## Implementation procedure
1. Name the affected user or system contract. 2. Establish onset and baseline. 3. Determine scope. 4. Correlate recent changes and dependency/resource signals. 5. State a leading hypothesis and one falsifying observation. 6. Choose the next bounded diagnostic action.

## Example

```markdown
## Triage checklist (first 10 minutes)

1. **Who is affected?** Journey + scope: `checkout` for all tenants / one region / one plan.
2. **Since when?** First bad datapoint in the user-facing SLI, not the first log error.
3. **What changed?** Deploys, flag flips, config, provider status, traffic shape in that window.
4. **How bad?** SLI now vs SLO (e.g. success 91 % vs 99.5 %), budget burn rate.
5. **Is it getting worse?** Queue depth / error rate trend over the last 15 min.
6. **Cheapest reversible mitigation?** Rollback > flag off > scale > manual data fix.
7. **Record** each step with timestamp and source in the incident channel.
```

## Failure modes
- treating the loudest log as root cause;
- declaring severity without user impact;
- running broad queries before narrowing scope;
- starting mitigation without ownership.

## Testing
Incident drills should provide deterministic symptoms and verify that the agent produces contract, scope, hypothesis, and next-action evidence.

## Review checklist
- [ ] user impact named; - [ ] onset evidence; - [ ] scope bounded; - [ ] hypothesis falsifiable; - [ ] next action safe;

## Related skills
rails-incident-engineering, rails-observability, rails-reliability-engineering, ruby-debugging