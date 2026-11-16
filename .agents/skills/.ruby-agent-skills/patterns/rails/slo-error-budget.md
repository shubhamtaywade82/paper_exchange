---
name: slo-error-budget
description: Define measurable service objectives and use their error budget to guide operational and engineering decisions.
family: rails
---

# SLO & Error Budget

## Problem

Teams track many metrics but do not define which reliability outcomes matter to users or how reliability failures change engineering decisions.

## Use when

Defining service reliability objectives, alerting, release gates, or incident priorities.

## Do not use when

The work is a single local bug with no service-level reliability contract.

## Repository inspection

Inspect user journeys, existing telemetry, incident history, business criticality, reporting windows, deployment cadence, and current alerting.

## Implementation procedure

1. Identify the critical user journey.
2. Choose an SLI that measures user-visible success, latency, freshness, or correctness.
3. Define the measurement window and target.
4. Derive the allowed error budget.
5. Define burn-rate or budget-consumption alerts.
6. Define engineering actions when budget is exhausted or rapidly consumed.
7. Revisit the target from observed evidence.

## Example

```markdown
## Checkout SLO

- **SLI:** successful `POST /checkout` responses (2xx or intentional 4xx) ÷ all checkout attempts, measured at the load balancer.
- **SLO:** 99.5 % over a rolling 28 days.
- **Error budget:** 0.5 % ≈ 3,360 failed checkouts per 672,000 attempts (current volume).

| Budget remaining | Policy                                                             |
|------------------|--------------------------------------------------------------------|
| > 50 %           | normal release cadence                                             |
| 10 – 50 %        | high-risk releases need progressive exposure                       |
| < 10 %           | freeze non-reliability changes to checkout; prioritize fixes       |

Alert: burn rate > 14.4× over 1 h (2 % of budget) pages on-call.
```

## Failure modes

- vanity infrastructure metric used as the SLI
- arbitrary high target
- alerting on every error
- budget exists but has no operational consequence
- changing the target to hide failures

## Testing

Test metric calculation against representative success/failure and latency data. Verify alert thresholds and budget actions.

## Review checklist

- [ ] user journey explicit
- [ ] SLI user-visible
- [ ] target/window explicit
- [ ] budget derived
- [ ] alert action explicit
- [ ] target evidence-based

## Related skills

- rails-reliability-engineering
- rails-observability
- rails-performance
