---
name: incident-timeline
description: Construct factual incident timelines from durable telemetry, deploy, control-plane, and operator-action timestamps.
family: rails
---

# Incident Timeline

## Problem
Post-incident narratives become unreliable when timelines are reconstructed from memory rather than timestamped evidence.

## Use when
- documenting incidents;
- correlating onset with changes;
- reviewing mitigation and recovery.

## Do not use when
- there is no operational event sequence to reconstruct;
- writing ordinary feature documentation.

## Repository inspection
Inspect log timestamps, telemetry timestamps, deployment history, feature-flag audit logs, queue/message events, and operator action records.

## Implementation procedure
1. Establish first known symptom. 2. Add alerts and acknowledgement. 3. Mark relevant changes. 4. Record scope changes. 5. Record diagnostic discoveries. 6. Record mitigation. 7. Record recovery and monitoring. 8. Separate observed facts from hypotheses.

## Example

```markdown
## INC-2026-031 timeline (UTC, from durable sources)

| Time     | Source                    | Observation (fact)                                          |
|----------|---------------------------|-------------------------------------------------------------|
| 09:12:04 | deploy log                | Release `a1b2c3d` promoted to production                    |
| 09:14:30 | APM                       | `POST /checkout` p95 1.2 s → 8.7 s                          |
| 09:15:10 | alert `checkout-latency`  | Paged on-call                                               |
| 09:21:45 | pg_stat_activity snapshot | 38 sessions waiting on `orders` row lock                    |
| 09:27:02 | deploy log                | Rollback to `9f8e7d6`                                       |
| 09:31:00 | APM                       | p95 back to 1.1 s; error rate < 0.1 %                       |

Hypothesis (unconfirmed): new `Order#recalculate!` holds a row lock across a provider call.
```

## Failure modes
- using memory as authoritative;
- mixing local and UTC timestamps without labeling;
- rewriting hypotheses as facts;
- omitting failed mitigations.

## Testing
Timeline tooling or templates should preserve timestamp ordering, source references, and explicit fact-versus-hypothesis labels.

## Review checklist
- [ ] timestamp source known; - [ ] changes marked; - [ ] failed actions preserved; - [ ] facts separated from hypotheses; - [ ] recovery recorded.

## Related skills
rails-incident-engineering, rails-observability, rails-production-runtime